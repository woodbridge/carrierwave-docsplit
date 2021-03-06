require 'carrierwave'
require 'fileutils'

ROOT = File.dirname(__FILE__)

$:.unshift File.join "../lib", ROOT

require 'carrierwave-docsplit'

require 'minitest/unit'

begin; require 'turn/autorun'; rescue LoadError; end

class TestUploader < CarrierWave::Uploader::Base
  extend CarrierWave::DocsplitIntegration

  def store_dir
    File.join(ROOT, 'uploads')
  end

  def self.file_path
    file = File.open(File.join(ROOT, 'data/w9.pdf'))
  end

  storage :file

  extract :images => { :to => :thumbs, :sizes => { :large => "300x", :medium => "500x" } }
end

class SingleSizeUploader < CarrierWave::Uploader::Base
  extend CarrierWave::DocsplitIntegration

  def store_dir
    File.join(ROOT, 'uploads')
  end

  storage :file

  def self.sizes
    { :large => "300x" }
  end

  def self.file_path
    file = File.open(File.join(ROOT, 'data/w9_single.pdf'))
  end

  extract :images => { :to => :thumbs, :sizes => self.sizes }
end

class TextExtractionUploader < CarrierWave::Uploader::Base
  extend CarrierWave::DocsplitIntegration

  def store_dir
    File.join(ROOT, 'uploads')
  end

  storage :file

  extract :text => { :to => :tail }
end

class Pig
  extend CarrierWave::Mount
  attr_accessor :tail
end

TEST_OUTPUT_PATH = File.join ROOT, 'uploads/w9'
SINGLE_OUTPUT_PATH = File.join ROOT, 'uploads/w9_single'

class TestCarrierWaveDocsplit < MiniTest::Unit::TestCase
  include CarrierWave::DocsplitIntegration

  def store_dir
    File.join(ROOT, 'uploads')
  end

  def setup
    @uploader = TestUploader.new
    @uploader.retrieve_from_store! File.join(ROOT, 'w9.pdf')

    CarrierWave.configure do |config|
      config.root = ROOT
    end
  end

  def extracted_images_exist?(uploader, output_path)
    File.exist?(output_path) && Dir.glob(File.join(output_path, "*")).any?
  end

  def test_that_read_accessor_is_being_generated
    assert @uploader.respond_to? :thumbs
  end

  def test_that_reader_returns_valid_hash
    if extracted_images_exist? @uploader, TEST_OUTPUT_PATH
      @uploader.retrieve_from_store!('w9.pdf')
    else
      file = File.open(TestUploader.file_path)
      @uploader.store! file
    end

    thumbs = @uploader.thumbs

    assert thumbs.include?('300x'), "Thumbs does not include 300x"
    assert thumbs.include?('500x'), "Thumbs does not include 500x"

    assert thumbs.values.all? { |val| val.is_a? Array }
  end

  def test_that_output_path_returns_nil_if_no_file_stored
    uploader = TestUploader.new
    assert_equal nil, uploader.output_path
  end

  def test_should_handle_one_size_gracefully
    uploader = SingleSizeUploader.new

    if extracted_images_exist? uploader, SINGLE_OUTPUT_PATH
      uploader.retrieve_from_store! 'w9_single.pdf'
    else
      file = File.open SingleSizeUploader.file_path
      uploader.store! file
    end

    assert uploader.thumbs.include?(SingleSizeUploader.sizes.values.first)
  end

  def test_that_text_extraction_should_raise_error_if_no_model
    assert_raises NoModelError do
      uploader = TextExtractionUploader.new
      uploader.enact_text_extraction
    end
  end

  def test_that_text_is_assigned_to_chosen_attribute
    Pig.mount_uploader :description, TextExtractionUploader
    pig = Pig.new
    pig.description = File.open(File.join(ROOT, 'data/w9.pdf'))
    assert_equal pig.tail, File.read(File.join(ROOT,'uploads/w9/w9.txt'))
  end
end
