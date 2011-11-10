#!/usr/bin/env ruby
# encoding: UTF-8
require 'bundler/setup'
require 'citrus_test'

require_relative '../lib/rtorctl'

GrammarTest.grammar_dir = "../grammars"

class TestControllerReply < GrammarTest
	SHIT = [
		"Hello, world!",
		"I♥UTF-8",
		"Newlines!!!" + ("\n" * 5000) + "T~I~L~D~E",
		"CRLFs!!!" + ("\r\n" * 5000) + "yo!",
		"\r\n.\r\x00\n\r\n",
		"",
		"¡Ruby Rocks!\r",
		"hello",
		"4200",
		"420A",
		"A420",
		"4\r\n20",
		"420\n",
		"420 ",
		"42",
		"4",
		"-1"
	]

	def test_data
		SHIT.each do |d|
			assert_parses(:data, d + "\r\n.\r\n", d)
			deny_parses(:data, d)
		end
	end

	def test_status_code
		1000.times do |i|
			assert_parses(:status_code, "%03d" % i, i)
		end

		SHIT.each do |s|
			deny_parses(:status_code, s)
		end
	end

	def test_reply_line
		SHIT.reject(&/\r\n/.method(:match)).each do |s|
			assert_parses(:reply_line, s + "\r\n", s)
			deny_parses(:reply_line, s)
		end
	end

	def test_data_reply_line
		SHIT.reject(&/\r\n/.method(:match)).each do |s|
			line = entropy( rand(1024) ).gsub("\r\n", 'i♥ruby')
			data = entropy( rand(4096) ).gsub("\r\n.\r\n", 'i♥ruby')
			status_code = rand(1000)

			assert_parses(:data_reply_line,
			              "%03d+%s\r\n%s\r\n.\r\n" % [status_code, line, data],
			              value: line, data: data, status_code: status_code)
		end

		SHIT.each do |s|
			deny_parses(:data_reply_line, s)
		end
	end

	{'mid' => '-', 'end' => ' '}.each do |line_type, sep|
		define_method("test_#{line_type}_reply_line") do
			{
				"060#{sep}Hi" => 60,
				"181#{sep}YYYYYYYYYYYYAO" => 181,
				"160#{sep}5 ☹ ♥ Æ ĸ ¸" => 160,
				"700#{sep}\n\n\r\r\r\r \nSPLEH" => 700,
				"000#{sep} " => 0,
				"991#{sep}kreiti" + ("\r"*500) + "n" + ("\n" * 500) => 991,
				"051#{sep}" => 51
			}.each do |str, status_code|
				assert_parses("#{line_type}_reply_line", str + "\r\n",
				              value: str[4..-1], status_code: status_code)
			end

			SHIT.each do |s|
				deny_parses("#{line_type}_reply_line", s)
			end
		end
	end

	def test_reply
		{
			"501 zed\r\n" => [501, %w{zed}, nil],
			"666-satan\r\n666 lucifer\r\n" => [666, %w{satan lucifer}, nil],
			"123+A\r\nDATA\r\n.\r\n123 B\r\n" => [123, %w{A B}, "DATA"],
			"000+hello\r\ngoodbye\r\n.\r\n000 !\r\n" => [0, %w{hello !}, "goodbye"],
			"151+bye\r\nhi\r\n\r\n.\r\n151 ¡\r\n" => [151, %w{bye ¡}, "hi\r\n"],
			"777+god\r\n\r\n.\r\n777 damn\r\n" => [777, %w{god damn}, ""],
			"011+\r\n\r\n.\r\n011 \r\n" => [11, ["", ""], ""],
			"189 \r\n" => [189, [""], nil],
			"001+A\r\nB\r\n.\r\n001+C\r\nD\r\n.\r\n001 E\r\n" =>
				[1, %w{A C E}, %w{B D}],
			"110+L1\r\nD1\r\n.\r\n110+L2\r\n\r\nD2\r\n.\r\n110 L3\r\n" =>
				[110, %w{L1 L2 L3}, ["D1", "\r\nD2"]]
		}.each do |str, (status, lines, data)|
			assert_parses(:reply, str, status_code: status, lines: lines, data: data)
		end

		SHIT.each do |s|
			deny_parses(:reply, s)
		end
	end

	private

	# Get count bytes of UTF-8 encoded entropy.
	def entropy(count)
		@devurand ||= open("/dev/urandom")
		@devurand.read(count).encode("UTF-8", undef: :replace, invalid: :replace)
	end
end
