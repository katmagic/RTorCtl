#!/usr/bin/ruby
require 'test/unit'
require 'parse_response'
require 'stringio'

class ParseResponseTest < Test::Unit::TestCase
	def setup
		@rtorctl = RTorCtl::RTorCtl.allocate
		class << @rtorctl
			public :get_response
			attr_accessor :connection

			def write(data)
				@connection.seek(0)
				@connection.write(data)
				@connection.seek(0)
			end
		end

		@rtorctl.connection = StringIO.new
		class << @rtorctl.connection
			alias :old_gets :gets
			def gets(sep="\r\n")
				s = old_gets(sep)
				s and s.chomp(sep)
			end
		end
	end

	OK = RTorCtl::Code.new(250)
	{
		:single_line_parse => {
			"250 OK\r\n" => [ OK, ["OK"] ]
		},

		:multi_line_parse_without_data => {
			"250-127.192.10.10=torproject.org\r\n250 1.2.3.4=tor.freehaven.net\r\n" =>
				[ OK, ["127.192.10.10=torproject.org", "1.2.3.4=tor.freehaven.net"] ],
			"250-ORPort=0\r\n250 SocksPort=9050\r\n" =>
				[ OK, ["ORPort=0", "SocksPort=9050"] ],
			"250-PROTOCOLINFO 1\r\n" +
			%Q{250-AUTH METHODS=COOKIE COOKIEFILE="/tmp/control_cookie"\r\n} +
			%Q{250-VERSION Tor="0.2.2.15-alpha-dev"\r\n} +
			"250 OK\r\n" =>
				[ OK, [
					"PROTOCOLINFO 1",
					'AUTH METHODS=COOKIE COOKIEFILE="/tmp/control_cookie"',
					'VERSION Tor="0.2.2.15-alpha-dev"',
					"OK"
				]]
		},

		:parse_with_empty_data => {
			"250+address-mappings/all=\r\n250 OK\r\n" =>
				[ OK, [["address-mappings/all=", []], "OK"] ]
		},

		:parse_with_data => {
			"250+entry-guards=\r\n" +
			"$3D13365C43A6E09F36DD633BEB7F405D36442E51~FSF up\r\n" +
			"$F2044413DAC2E02E3D6BCF4735A19BCA1DE97281=gabelmoo up\r\n.\r\n" +
			"250 OK\r\n" =>
				[OK, [
					["entry-guards=", [
						"$3D13365C43A6E09F36DD633BEB7F405D36442E51~FSF up",
						"$F2044413DAC2E02E3D6BCF4735A19BCA1DE97281=gabelmoo up"
					]],
					"OK"
				]]
		}
	}.each do |meth_name, inout|
		define_method("test_#{meth_name}") do
			inout.each do |input, output|
				@rtorctl.write(input)
				assert_equal(
					output, @rtorctl.get_response(), "parsing #{input.inspect}"
				)
			end
		end
	end
end
