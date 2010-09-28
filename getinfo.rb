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

		def getconf(*keywords)
			# tor.getconf(:SocksPort) # "9050"
			# tor.getconf(:SocksPort, :ControlPort)
			# # {"SocksPort"=>"9050", "ControlPort"=>"9051"}

			@connection.puts("GETCONF #{keywords.join(" ")}")
			code, response = get_response()

			code.raise()

			if keywords.length == 1
				return response[0].split("=", 2)[1]

			else
				results = Hash.new

				response.each do |x|
					key, value = x.split("=", 2)
					results[key] = value
				end

				return results
			end
		end
	end
end
