#!/usr/bin/ruby
require 'socket'
require 'quote'

module RTorCtl
	class Connection
		include RTorCtl

		attr_writer :password, :ctlport, :connection

		def initialize(password, ctlport=9051)
			@password = password
			@ctlport = ctlport
		end

		def connect()
			@connection = TCPSocket.new( "127.0.0.1", @ctlport )
		end

		def puts(line)
			self.write( line + "\r\n" )
		end

		def gets(sep="\r\n")
			s = @connection.gets(sep)
			return nil unless s
			s.chomp("\r\n")
		end

		def write(data)
			@connection.write(data)
		end
	end
end
