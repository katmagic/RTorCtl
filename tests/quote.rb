#!/usr/bin/ruby
require 'quote'
require 'test/unit'
require 'yaml'


class QuoteTest < Test::Unit::TestCase
	include RTorCtl

	@@quotes = YAML.load_file('tests/quotes.yaml')

	def test_quote
		@@quotes.each do |unquoted, quoted|
			assert_equal( quoted, quote(unquoted), "quoting #{unquoted.inspect}" )
		end
	end

	def test_unquote
		@@quotes.each do |unquoted, quoted|
			assert_equal( unquoted, unquote(quoted), "unquoting #{quoted.inspect}" )
		end
	end
end
