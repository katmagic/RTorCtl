#!/usr/bin/ruby
# This file contains methods that probably shouldn't be part of a library, but
# that are very nice to have when just popping into irb and inspecting your Tor.
require 'ip_address'

module RTorCtl
	# Since an exit policy can allow exit to hosts on different ports, we test
	# whether an exit will exit to a given port based on whether it will exit to
	# EXIT_TESTING_HOST:port.
	EXIT_TESTING_HOST = IPAddress.new('14.29.7.8')

	class Relay
		def exit?(port=80)
			exit_policy.accepts?(EXIT_TESTING_HOST, port)
		end
	end

	class RTorCtl
		# An Array of the last _count_ exits that came online that exit to _port_.
		def latest_exits(port=80, count=5)
			relays.find_all{ |r| r.exit?(port) }.sort{ |a, b|
				a.uptime <=> b.uptime
			}[0...count]
		end

		# Send a NEWNYM event to Tor.
		def newnym()
			signal(:NEWNYM)
		end

		# What version of Tor are we connected to?
		def tor_version
			getinfo("tor-version")
		end

		# Shutdown Tor. If _force_ is set, we send HALT, otherwise we send SHUTDOWN.
		def quit(force=false)
			signal( force ? :HALT : :SHUTDOWN )
		end
	end
end
