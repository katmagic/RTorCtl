#!/usr/bin/ruby
require 'codes'
require 'exceptions'

module RTorCtl
	class RTorCtl
		private

		def get_response()
			# Get a response back from Tor, returning a two-element array whose first
			# member is a response code (Integer) and second member is an array whose
			# members are either a String containing the line recieved or an Array
			# containing a line and its associated data, represented as an array of
			# stripped lines.

			lines = []
			while line = @connection.gets()
				# The statements like `when (boolean_expr and line)` will be executed
				# when boolean_expr is true.

				case line
					when /^(\d+)\+(.*)$/
						data = @connection.gets("\r\n.\r\n")
						lines << [$2, data.split("\r\n")]

					when /^(\d+)-(.*)$/
						lines << $2

					when /^(\d+) (.*)$/
						code = $1.to_i
						lines << $2
						break

					else
						raise RTorCtlError, "we couldn't handle #{line.inspect}"
				end
			end

			return [Code.new(code), lines]
		end
	end
end
