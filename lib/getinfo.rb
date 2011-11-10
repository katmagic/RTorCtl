#!/usr/bin/env ruby

module RTorCtl
	# This module implements GETINFO and GETCONF.
	module GetInfo
		# Get values for the keys specified. If only one key is specified, we will
		# return only that configuration option; otherwise, we return a Hash of
		# converted configuration options. If not all of the keys exist, we raise
		# KeyError.
		def getconf(*keys)
			r = sendrecv("GETCONF #{keys.join(" ")}")

			if r.status_code == 552
				raise KeyError, (r.value rescue r.lines)
			elsif r.status_code != 250
				# This shouldn't happen.
				raise RuntimeError, r.value
			end

			results = Hash.new
			r.lines.each do |l|
				key, val = *l.split("=", 2)
				key = key.to_sym
				results[key] = val
			end

			case keys.length
				when 0 then {}
				when 1 then results.first[1]
				else results
			end
		end

		# Get the info key key. If key is invalid, we raise KeyError; otherwise, we
		# return a String.
		def getinfo(key)
			r = sendrecv("GETINFO #{key}")

			if r.status_code == 552
				raise KeyError, r.value
			elsif r.status_code != 250
				# This shouldn't happen.
				raise RuntimeError, r.value
			end

			return (r.data || r.lines[0] || r.value || "")
		end
	end
end
