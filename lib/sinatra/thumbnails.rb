require 'sinatra/base'

module Sinatra
  module Thumbnails
    module Settings
      def method_missing(name, *args)
        if (name.to_s =~ /=$/)
          key = name.to_s[0..-2].to_sym
          raise NoMethodError unless self[key]
          raise ArgumentError if args.length != 1
          Thumbnails::Settings.send(:define_method, name) do |val|
            self[key] = val
          end
          self.send(name, args[0])
        elsif args.length == 0
          raise NoMethodError unless self[name]
          Thumbnails::Settings.send(:define_method, name) do
            self[name]
          end
          self.send(name)
        else
          raise ArgumentError
        end
      end
    end
    
    def self.make_thumb(file, format, original_extension)
      original_extension ||= "jpg"
      thumbnail_file = File.join(settings.thumbnail_path, "#{format}/#{file}")
      FileUtils.mkdir_p File.dirname(thumbnail_file)
      orig_file = File.join(settings.image_path_prefix, file.gsub(/(.*\.)(.*$)/,"\\1#{original_extension}"))

      unless File.exists?(thumbnail_file) and (File.stat(thumbnail_file).mtime >= File.stat(orig_file).mtime)
        
        if original_extension =~ /mov$/
          ffmpeg(orig_file, thumbnail_file, format)
        else
          convert(orig_file, thumbnail_file, format)
        end
      end
      thumbnail_file
    end

    def self.im_version
      `convert --version` =~ /Version: ImageMagick ([\d\.]+)/
      Regexp.last_match(1).split('.').map{|s|s.to_i}
    end

    def self.convert(src, dest, format)
      if (format =~ /(.*)-crop$/) 
        if (im_version <=> [6,6,4]) >= 0
          format = $1 + "^" + " -gravity center -extent " + $1
        else
          format = $1
        end
      end
      FileUtils.mkdir_p(File.dirname(dest))
      command = "#{Sinatra::Thumbnails.settings.convert_executable} -define jpeg:size=400x400 '#{src}' -thumbnail #{format} '#{dest}'"
      # puts "Sinatra::Thumbnails: issuing \"#{command}\""
      run_command(command)
    end
    
    def self.ffmpeg(src, dest, format)
      puts "making movie thumb on the fly"
      seconds = (src =~ /\.ss([\d]+)/) ? Regexp.last_match(1).to_i : 0 
      command = "#{Sinatra::Thumbnails.settings.ffmpeg_executable} -y -i '#{src}' -an -ss #{seconds} -r 1 -vframes 1 -f mjpeg  '#{dest}'"
      # puts "Sinatra::Thumbnails: issuing \"#{command}\""
      run_command(command)
      convert(dest, dest, format)
    end
    
    def self.run_command(command)
      output = `#{command} 2>&1`
      raise "couldn't run #{command}: #{output}" unless $?.success?
    end

    
    def self.settings
      @@settings ||= { :convert_executable  => 'convert'     ,   
                       :ffmpeg_executable   => 'ffmpeg'      ,   
                       :thumbnail_path      => 'public/thumbnails'  ,
                       :image_path_prefix   => 'public'             ,
                       :thumbnail_extension => 'png'         ,   
                       :thumbnail_format    => '100x100'       }.extend(Thumbnails::Settings) 
    end

    module Helpers
      def thumbnail_url_for(asset, format = Thumbnails.settings.thumbnail_format)
        almost_original = asset.gsub(/(.*\.)(.*$)/,"\\1#{Thumbnails.settings.thumbnail_extension}")
        original_extension = Regexp.last_match(2)
        "#{Thumbnails.settings.thumbnail_path}/#{format}/#{almost_original}?original_extension=#{original_extension}"
      end
    end

    def self.registered(app)
      app.helpers Helpers

      # gotta make this a regexp, :asset wont match stuff with "/" in it
      app.get /#{settings.thumbnail_path}\/([^\/]+)\/(.*)$/ do
          send_file Thumbnails.make_thumb(params[:captures][1], params[:captures][0], params[:original_extension])
      end
    end
  end
  register Thumbnails
end
