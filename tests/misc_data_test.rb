#!/usr/bin/env ruby
# encoding: UTF-8
require 'bundler/setup'
require 'citrus_test'

GrammarTest.grammar_dir = "../grammars"

class TestMiscData < GrammarTest
	def test_nickname
		%w{specialK 142978 36degrees}.each do |nick|
			assert_parses(:nickname, nick)
		end
		
		%w{specialĸ afriendwithbreastsandalltherest strange♥}.each do |nick|
			deny_parses(:nickname, nick)
		end
	end
	
	def test_ipv4_address
		%w{127.0.0.1 192.168.1.1 255.255.255.255 0.0.0.0 11.9.200.1}.each do |addr|
			assert_parses(:ipv4_address, addr)
		end
		
		%w{1.2.3.4.5 17f.0.0.1 notanip 1.1.1.1¡ 256.1.1.1 ♥ftw}.each do |addr|
			deny_parses(:ipv4_address, addr)
		end
	end
	
	def test_int
		%w{2 03 005 0007 00011 130017 1900023 2931374 000001434753}.each do |num|
			assert_parses(:int, num, num.to_i)
		end
		
		%w{notanint 2noram1 0x51 hexisntallowed 0b11 ♥ ฿1429.78 69°}.each do |num|
			deny_parses(:int, num)
		end
	end
	
	def test_time
		%w{00:00:00 51:37:48 10:10:10 59:59:59}.each do |time|
			assert_parses(:time, time)
		end
		
		%w{00:0:00 111:11:11 7:7:7 777 07:07:07-}.each do |not_time|
			deny_parses(:time, not_time)
		end
	end

	def test_date	
		%w{0000-01-01 9999-11-05 7815-10-30}.each do |date|
			assert_parses(:date, date)
		end
		
		%w{0000-01-001 1234--05-06 1023-4-5-6 no ¡ ☹}.each do |not_date|
			deny_parses(:date, not_date)
		end
	end
	
	def test_date_time
		{
			"2015-04-23 09:06:40" => 1429780000,
			"2011-11-04 05:41:06" => 1320385266,
			"0000-10-11 01:35:48" => -62142675852
		}.each do |str, int|
			assert_parses(:date_time, str, Time.at(int).utc)
		end
		
		["2015-04-23 09:06:40 EST", "2015--04-23 09:06:40"].each do |not_date_time|
			deny_parses(:date_time, not_date_time)
		end
	end
	
	def test_base64
		{
			"Rm9sbG93IEB0aGVtYWdpY2Fsa2F0IG9uIFR3aXR0ZXIh"\
				=> "Follow @themagicalkat on Twitter!",

			"QWxsIHlvdXIgYmFzZSBhcmUgYmVsb25nIHRvIHVzIQ=="\
				=> "All your base are belong to us!",

			""\
				=> "",

<<B64_DATA.strip\
QSBBJ3MgQU9MIEFPTCdzIEFhY2hlbiBBYWNoZW4ncyBBYWxpeWFoIEFhbGl5YWgncyBBYXJvbiBB\r
YXJvbidzIEFiYmFzIEFiYmFzaWQgQWJiYXNpZCdzIEFiYm90dCBBYmJvdHQncyBBYmJ5IEFiYnkn\r
cyBBYmR1bCBBYmR1bCdzIEFiZSBBYmUncyBBYmVsIEFiZWwncyBBYmVsYXJkIEFiZWxhcmQncyBB\r
YmVsc29uIEFiZWxzb24ncyBBYmVyZGVlbiBBYmVyZGVlbidzIEFiZXJuYXRoeSBBYmVybmF0aHkn\r
cyBBYmlkamFuIEFiaWRqYW4ncyBBYmlnYWlsIEFiaWdhaWwncyBBYmlsZW5lIEFiaWxlbmUncyBB\r
Ym5lciBBYm5lcidzIEFicmFoYW0gQWJyYWhhbSdzIEFicmFtIEFicmFtJ3MgQWJyYW1zIEFic2Fs\r
b20gQWJzYWxvbSdzIEFidWphIEFieXNzaW5pYSBBYnlzc2luaWEncyA==
B64_DATA
=> "A A's AOL AOL's Aachen Aachen's Aaliyah Aaliyah's Aaron Aaron's Abbas
Abbasid Abbasid's Abbott Abbott's Abby Abby's Abdul Abdul's Abe Abe's Abel
Abel's Abelard Abelard's Abelson Abelson's Aberdeen Aberdeen's Abernathy Abernathy's Abidjan Abidjan's Abigail Abigail's Abilene Abilene's Abner Abner's Abraham Abraham's Abram Abram's Abrams Absalom Absalom's Abuja Abyssinia Abyssinia's ".gsub("\n", " ")
		}.each do |b64, str|
			assert_parses(:base64_data, b64, str)
		end
	end

	def test_bool
		assert_parses(:bool, "0", false)
		assert_parses(:bool, "1", true)
		%w{false 2 00}.each do |not_bool|
			deny_parses(:bool, not_bool)
		end
	end
	
	def test_port_range
		{
			"0-65536" => (0..65536),
			"14-297" => (14..297),
			"1-511927" => (1..511927)
		}.each do |str, range|
			assert_parses(:port_range, str, range)
		end
		
		%w{0--1 -124 0- 1-100a - * notarange ฿}.each do |not_range|
			deny_parses(:port_range, not_range)
		end
	end
end
