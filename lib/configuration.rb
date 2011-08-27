#!/usr/bin/env ruby

module RTorCtl
	module Configuration
		# Get a configuration key from the controller, returning it as a String.
		def getconf(key)
			r = sendrecv("GETCONF #{key}")

			case r.status_code
				when 250 then r.value.split("=", 2)[1]
				when 552 then raise(KeyError, "unrecognized configuration key")
				else raise(ControllerError.new(r))
			end
		end
	end
end

