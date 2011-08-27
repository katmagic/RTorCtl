#!/usr/bin/env ruby
require 'bundler/setup'
require 'citrus'
require 'socket'

# Load all of our grammars.
def load_grammars()
	# This is a really long way of saying ../grammars/.
	dot_dot = File.dirname(File.absolute_path(File.dirname(__FILE__)))
	grammar_dir = File.join(dot_dot, 'grammars')

	Dir.entries(grammar_dir).grep(/\.citrus$/) do |grammar|
		Citrus.load( File.join(grammar_dir, grammar) )
	end
end
load_grammars()

module RTorCtl
	class RTorCtl
		def initialize()
			@connection = TCPSocket.new('127.0.0.1', 9051)
		end

		def write(str)
			@connection.write(str + "\r\n")
		end

		# Block until we get a single response from the controller, then return it.
		def get_response()
			data = ""

			while true
				data += @connection.read(4)

				case data[-1]
					when ' '
						data += @connection.gets("\r\n")
						return data

					when '-'
						data += @connection.gets("\r\n")

					when '+'
						data += @connection.gets("\r\n.\r\n")
				end
			end

			data
		end
	end
end

