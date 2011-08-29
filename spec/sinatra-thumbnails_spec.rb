$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'sinatra/thumbnails'
require 'rack/test'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

module FixtureHelper
  FIXTURE_DIR = File.expand_path('fixtures', File.dirname(__FILE__))

  def create_fixtures
    FileUtils.mkdir_p(fixtures_path)
    Sinatra::Base.set :root, fixtures_path
    Sinatra::Base.set :public, File.join(fixtures_path, "public")

    images_dir = File.join(Sinatra::Base.public,"images")
    FileUtils.mkdir_p(images_dir)

    some_images_dir = File.join(File.dirname(__FILE__), "test_assets") 

    Dir.glob(File.join(some_images_dir, "*")) do |file|
      FileUtils.copy(file, images_dir)
    end
  end

  def remove_fixtures
    FileUtils.rm_r(fixtures_path, :force => true)
  end

  def fixtures_path
    FixtureHelper::FIXTURE_DIR
  end
end

RSpec.configure do |config|
  include Sinatra::Thumbnails::Helpers
  include Rack::Test::Methods
end
# end of former spec_helper.rb

describe "unit tests" do
  it "calculate thumbnail url" do
    thumbnail_url_for("something.jpg").should match /^#{Sinatra::Thumbnails.settings.thumbnail_path}
                                                     \/#{Sinatra::Thumbnails.settings.thumbnail_format}
                                                     \/something\.#{Sinatra::Thumbnails.settings.thumbnail_extension} # 
                                                     \?original_extension=jpg$/x   
  end
end

# TODO: An idea but doesn't work
#
#  module RSpec
#   module Mocks
#     class MessageExpectation
#       def and_proxy_to_original_method
#         # @original_method = @error_generator.target.method(@sym).to_proc
#         @method_block = Proc.new do |*args|
#           @error_generator.target.__send__(@sym)
#           # @original_method.call(*args)
#         end
#         self
#       end
#     end

#     class ErrorGenerator
#       attr_reader :target
#     end
#   end
# end

describe "functional tests" do
  include FixtureHelper

  before do
    create_fixtures
    Dir.chdir(fixtures_path)
  end

  after do
    Dir.chdir(File.dirname(__FILE__))
    remove_fixtures
  end

  def app
    Sinatra::Application
  end

  def thumbnail_file_from_url(url)
    File.join(url.sub(/\?.*$/, ""))
  end

  it "should serve a thumbnail file" do
    thumbnail_url = thumbnail_url_for("images/something.jpg") 
    get thumbnail_url
    last_response.should be_ok
    File.exist?(thumbnail_file_from_url(thumbnail_url)).should be_true 
  end

  it "should detect a cached version" do
    original_method = Sinatra::Thumbnails.method(:convert)
    Sinatra::Thumbnails.should_receive(:convert).exactly(1).times do |*args|
      original_method.call(*args)
    end
    # TODO: see above
    # Sinatra::Thumbnails.should_receive(:convert).exactly(1).once.and_proxy_to_original_method
    thumbnail_url = thumbnail_url_for("images/something.jpg") # 
    get thumbnail_url
    last_response.should be_ok
    File.exist?(thumbnail_file_from_url(thumbnail_url)).should be_true
    get thumbnail_url
    last_response.should be_ok
  end
  
end
