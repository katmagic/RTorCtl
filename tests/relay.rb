#!/usr/bin/ruby
require 'test/unit'
require 'yaml'
require 'rtorctl'

Dir.chdir( File.dirname(File.expand_path(__FILE__)) )

RELAYS = Dir.entries("descriptors").grep(/^(.*)\.yaml$/){$1}

class RelayTest < Test::Unit::TestCase
	def test_descriptor_parsing
		RELAYS.each do |r|
			verifier = YAML.load_file("descriptors/#{r}.yaml")
			descriptor = File.open("descriptors/#{r}.desc").read()
			parsed = RTorCtl::Relay.new(nil, descriptor)

			verifier.each do |attr, expected|
				begin
					actual = parsed.send(attr)
				rescue NoMethodError
					flunk( "#{r} doesn't have expected attribute #{attr}" )
				else
					assert_equal( expected, actual, "parsing #{r}'s #{attr}" )
				end
			end
		end
	end
end
