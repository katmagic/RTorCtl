#!/usr/bin/ruby
require 'test/unit'
require 'yaml'
require 'rtorctl'


class QuoteTest < Test::Unit::TestCase
	include RTorCtl

	@@quotes = YAML.load_file("#{File.dirname(__FILE__)}/data/quotes.yaml")

	def test_quote
		@@quotes.each do |unquoted, quoted|
			assert_equal( quoted, Quote[unquoted], "quoting #{unquoted.inspect}" )
		end
	end

	def test_unquote
		@@quotes.each do |unquoted, quoted|
			assert_equal( unquoted, Unquote[quoted], "unquoting #{quoted.inspect}" )
		end
	end
end
