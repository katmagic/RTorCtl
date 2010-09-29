#!/usr/bin/ruby
require 'test/unit'
require 'rtorctl'

class GetInfoTest < Test::Unit::TestCase
	def setup
		@rtor = RTorCtl::RTorCtl.allocate
		class << @rtor
			public :convert_option_getter, :convert_option_setter
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
		CONVERSIONS.each do |option, ruby_repr, tor_repr|
			assert_equal(
				ruby_repr,
				@rtor.convert_option_getter(option, tor_repr),
				"convert_option_getter(#{option.inspect}, #{tor_repr.inspect})"
			)

			assert_equal(
				tor_repr,
				@rtor.convert_option_setter(option, ruby_repr),
				"convert_option_setter(#{option.inspect}, #{ruby_repr.inspect})"
			)
		end
	end
end
