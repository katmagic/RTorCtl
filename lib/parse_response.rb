#!/usr/bin/ruby
require 'codes'
require 'exceptions'

module RTorCtl
	class RTorCtl
		private

=begin
Get a response from Tor.

@return [Code, Array]
 The members of the +Array+ are either
 * a +String+ containing a one-line response; or
 * an +Array+ containing the first line of the response (that is given
   alongside the response code) and an +Array+ of lines with their terminators
   stripped that represent the part of the response associated with the first
   element in the innermost +Array+.
=end
		def get_response()
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
