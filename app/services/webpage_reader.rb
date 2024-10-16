# frozen_string_literal: true

require 'open-uri'
require 'rubygems'
require 'readability'

class WebpageReader
  class << self
    def extract_main_content(url)
      source = OpenURI.open_uri(url).read
      Readability::Document.new(source, remove_empty_nodes: true).content
    end
  end
end
