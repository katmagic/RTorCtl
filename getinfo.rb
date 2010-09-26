#!/usr/bin/ruby
require 'parse_response'

module RTorCtl
	class RTorCtl
		def getinfo(*keywords)
			# Get some data from Tor in a somewhat generic fashion. Return a hash with
			# keywords mapped to their returned values.

			@connection.puts("GETINFO #{keywords.join(" ")}")
			code, response = get_response()

			code.raise()

			info = Hash.new
			response[0...-1].each do |r|
				if r.is_a? Array
					info[r[0].chomp("=").to_sym] = r[1]
				else
					name, val = r.split("=", 2)
					info[name.to_sym] = val
				end
			end

			keywords.length == 1 ? info.first[1] : info
		end
	end
end
