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

			receiving_data = false;
			first_line = false
			current_data = nil

			while line = @connection.gets()
				# The statements like `when (boolean_expr and line)` will be executed
				# when boolean_expr is true.

				case line
					when (receiving_data and line == "." and line)
						receiving_data = false
						lines << current_data
						current_data = nil

					when (receiving_data and !first_line and line)
						current_data[1] << line

					when /^(\d+)\+(.*)$/
						lines << current_data if receiving_data
						current_data = [$2, []]
						receiving_data = true
						first_line = true

					when /^(\d+)-(.*)$/
						lines << current_data if receiving_data
						lines << $2

					when (receiving_data and line)
						current_data[1] << line
						first_line = false

					when /^(\d+) (.*)$/
						code = $1.to_i
						lines << current_data if receiving_data
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
