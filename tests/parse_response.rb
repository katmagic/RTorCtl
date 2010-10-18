#!/usr/bin/ruby
require 'test/unit'
require 'stringio'
require 'rtorctl'
require 'yaml'

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

	responses = YAML.load_file( "#{File.dirname(__FILE__)}/data/responses.yaml" )
	responses.each do |meth_name, inout|
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
