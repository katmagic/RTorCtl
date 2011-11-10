#!/usr/bin/env ruby

module RTorCtl
	module MiscMethods
		# Map from to to.
		def map_addr(from, to)
			r = sendrecv("MAPADDRESS #{from}=#{to}")
			raise(RuntimeError, r.value) if r.status_code != 250
		end
	end
end
