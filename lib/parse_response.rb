#!/usr/bin/ruby
require 'codes'
require 'exceptions'
require 'events'

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
			@responses.deq()
		end

		# We read responses from +@connection+ and either put them in +@responses+
		# so get_response() will return them or send them to handle_async()
		# immediately.
		def response_parser_loop()
			lines = []

			while line = @connection.gets()
				case line
					when /^(\d+)\+(.*)$/
						data = @connection.gets("\r\n.\r\n")
						lines << [$2, data.split("\r\n")]

					when /^(\d+)-(.*)$/
						lines << $2

					when /^(\d+) (.*)$/
						code = $1.to_i
						lines << $2

						if code == 650 # This is an asynchronous response.
							handle_async(lines)
						else # This is a normal response that get_response() should return.
							@responses.enq( [Code.new(code), lines] )
						end

						lines = []

					else
						raise RTorCtlError, "we couldn't handle #{line.inspect}"
				end
			end
		end
	end
end
