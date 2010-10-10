#!/usr/bin/ruby
require 'socket'
require 'quote'

module RTorCtl
	# This class holds a connection to Tor's control port.
	class Connection
		def initialize(ctlport=9051)
			@ctlport = ctlport
		end

		# Make the connection to the control port.
		def connect()
			@connection = TCPSocket.new( "127.0.0.1", @ctlport )
		end

		# Write a line to Tor.
		def puts(line)
			self.write( line + "\r\n" )
			STDOUT.puts("C: #{line.inspect}") if $DEBUG
		end

		# Retrieve a string from Tor terminated with +sep+.
		# @return [String] the recieved string with +sep+ removed
		def gets(sep="\r\n")
			s = @connection.gets(sep)
			return nil unless s
			s[0...-sep.length].tap{|x| STDOUT.puts("S: #{x.inspect}") if $DEBUG}
		end

		# Write raw data to Tor.
		def write(data)
			@connection.write(data)
		end
	end
end
