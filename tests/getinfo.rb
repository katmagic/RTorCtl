#!/usr/bin/ruby
require 'test/unit'
require 'getinfo'

class GetInfoTest < Test::Unit::TestCase
	def setup
		@rtor = RTorCtl::RTorCtl.allocate
		class << @rtor
			public :convert_option
		end
	end

	CONVERSIONS = [
		[ :TrackHostExits, ['bob.com', 'l.org'], "bob.com,l.org" ],
		[ :ControlListenAddress, '127.0.0.1:9051', '127.0.0.1:9051'],
		[ :SafeLogging, true, '1' ],
		[ :LongLivedPorts, [1, 2, 3, 4], '1,2,3,4' ],
		[ :SocksPort, 9050, '9050' ]
	]
	def test_option_conversion
		CONVERSIONS.each do |option, output, input|
			assert_equal(
				output,
				@rtor.convert_option(option, input),
				"convert_option(#{option.inspect}, #{input.inspect})"
			)
		end
	end
end
