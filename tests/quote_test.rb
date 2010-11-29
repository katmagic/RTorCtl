#!/usr/bin/ruby
require 'test/unit'
require 'quote'

QUOTES = {
	"hello, world!" => '"hello, world!"',
	"I was hanging from a tree\nunaccustomed to such violence" =>
		%Q{"I was hanging from a tree\\\nunaccustomed to such violence"},
	"\n"*600 => '"' + "\\\n"*600 + '"',
	"27" => '"27"',
	"\x01\x00\x02" => %Q{"\001\\\000\002\"},
	"won't give up; it wants me dead" => %q{"won't give up; it wants me dead"},
	"g*d d**n this noise inside my head" => '"g*d d**n this noise inside my head"'
}

class QuoteTest < Test::Unit::TestCase
	def test_quoting
		QUOTES.each do |unquoted, quoted|
			assert_equal(
				quoted,
				RTorCtl::Quote[unquoted],
				"#{unquoted.inspect} should quote to #{quoted.inspect}"
			)

			assert_equal(
				unquoted,
				RTorCtl::Unquote[quoted],
				"#{quoted.inspect} should unquote to #{unquoted.inspect}"
			)
		end
	end
end
