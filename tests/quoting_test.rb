#!/usr/bin/env ruby
# encoding: UTF-8
require 'bundler/setup'
require 'citrus_test'

require_relative '../lib/quoting'

GrammarTest.grammar_dir = "../grammars"

class TestDoubleQuotedString < GrammarTest
	def test_unquoted_char
		%w{' a b c d e - : ^ ( ! . }.each do |c|
			assert_parses(:unquoted_char, c, c)
		end

		%W{♥ € \\ " \n \ « ¡ \0 hi two for-}.each do |c|
			deny_parses(:unquoted_char, c)
		end
		deny_parses(:unquoted_char, '')
	end

	def test_quoted_char
		%w{\♥ \" \\\\ \¡ \« \¸ \ñ \¯ \⁺}.each do |c|
			assert_parses(:quoted_char, c, c[1])
		end

		%w{♥ \k k ¡♥♥¡ po!* 8€ \\}.each do |c|
			deny_parses(:quoted_char, c)
		end
		deny_parses(:quoted_char, '')
	end

	def test_qatom
		{
			'\♥' => '♥', '\⁽' => '⁽', '\⚧' => '⚧', '\⚳' => '⚳', '\⚑' => '⚑',
			'k' => 'k', 'P' => 'P', "\\\0" => "\0", "\\\n" => "\n", '\«' => '«'
		}.each do |u, p|
			assert_parses(:qatom, u, p)
		end

		%w{hi ho ♥ \k \m \¡¡ -- ¡\¸ °ĸ ° ja«l &$ —— :' *% -k \o \m \p}.each do |c|
			deny_parses(:qatom, c)
		end
		deny_parses(:qatom, '')
	end

	def test_qcontent
		{
			'\¡Oh Em Gee!' => '¡Oh Em Gee!',
			'\"infinity\°F' => '"infinity°F',
			'avalanche' => 'avalanche',
			'\"posthumous groundhog\"' => '"posthumous groundhog"',
			'\…\…\…\…\…' => '……………',
			'' => ''
		}.each do |u, p|
			assert_parses(:qcontent, u, p)
		end

		%w{♥sweet♥ áĺíéńź hea\rt kĸ- meg\ son"ic tomb¡}.each do |s|
			deny_parses(:qcontent, s)
		end
	end

	def test_string
		{
			'"hello, world!"' => 'hello, world!',
			'"\¡Adios, mundo!"' => '¡Adios, mundo!',
			'"\"kremey"' => '"kremey',
			'"\♥"' => '♥',
			'""' => ''
		}.each do |u, p|
			assert_parses(:string, u, p)
		end

		['', '"♥LOVE"', "\"\n\"", 'c"hi"', '"hi"c', '"yo', '"yo\\'].each do |s|
			deny_parses(:string, s)
		end
	end
end

class QuotingTest
	include RTorCtl::Quoting

	def test_quoting_and_unquoting
		{
			%q{Hi!} => %q{"Hi!"},
			%q{¡Hola!} => %q{"\¡Hola!"},
			%q{"rabbits"} => %q{"\"rabbits\""},
			%Q{"\r\nK¡"\n\\} => %Q{"\\"\\\r\\\nK\\¡\\"\\\n\\\\"},
			%q{} => %q{""},
			%q{\\} => %q{"\\"}
		}.each do |unquoted, quoted|
			assert_equal(quoted, quote(unquoted), "quoting failed")
			assert_equal(unquoted, unquote(quoted), "unquoting failed")
		end
	end
end

