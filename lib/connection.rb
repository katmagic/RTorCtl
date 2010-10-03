#!/usr/bin/ruby
require 'socket'
require 'quote'

module RTorCtl
	class Connection
		def initialize(ctlport=9051)
			@ctlport = ctlport
		end

		def connect()
			@connection = TCPSocket.new( "127.0.0.1", @ctlport )
		end

		def puts(line)
			self.write( line + "\r\n" )
			STDOUT.puts("C: #{line.inspect}") if $DEBUG
		end

		def gets(sep="\r\n")
			s = @connection.gets(sep)
			return nil unless s
			s[0...-sep.length].tap{|x| STDOUT.puts("S: #{x.inspect}") if $DEBUG}
		end

		def write(data)
			@connection.write(data)
		end
	end
end
