#!/usr/bin/ruby
require 'test/unit'
require 'rtorctl'
require 'yaml'

class GetInfoTest < Test::Unit::TestCase
	def setup
		@rtor = RTorCtl::RTorCtl.allocate
		class << @rtor
			public :convert_option_getter, :convert_option_setter
		end
	end

	bd = File.dirname(__FILE__)
	CONVERSIONS = YAML.load_file("#{bd}/data/option_conversions.yaml")
	def test_option_conversion
		CONVERSIONS.each do |option, (ruby_repr, tor_repr)|
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
