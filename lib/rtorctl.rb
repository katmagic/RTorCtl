#!/usr/bin/env ruby
require 'bundler/setup'
require 'socket'

require_relative 'grammars'
require_relative 'quoting'

module RTorCtl
	class RTorCtl
		include Quoting

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

