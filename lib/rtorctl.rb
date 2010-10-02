#!/usr/bin/ruby
# RTorCtl presents a Rubyonic interface to Tor's control port.

require 'codes'
require 'quote'
require 'exceptions'
require 'exit_policy'
require 'connection'
require 'parse_response'
require 'getinfo'
require 'relay'

module RTorCtl
	def self.new
		RTorCtl.new
	end

	class RTorCtl
		attr_reader :relays, :connection

		def initialize(passwd=:IMPLIED, ctlport=9051)
			if passwd == :IMPLIED
				@passwd = determine_control_password()
			else
				@passwd = passwd
			end
			@ctlport = ctlport

			@connection = Connection.new(@ctlport)

			@connection.connect()
			authenticate()

			@relays = Relays.new(self)
		end

		def determine_control_password
			ENV['TORCTL_PASSWD'] ||
			( open(ENV['TORCTL_PASSWD_FILE']).read() rescue nil ) ||
			(ARGV.grep(/^-passwd=(.*)/) && $1) ||
			(ARGV.grep(/^-passwd_file=(.*)/) && $1) \
			or raise RTorCtlError, "couldn't determine password!"
		end

		def signal(sig)
			@connection.puts("SIGNAL #{sig}")
			get_response()[0].raise()
		end

		private

		def authenticate()
			passwd = @passwd.bytes.map{|x| "%02X" % x}.join
			@connection.puts( "AUTHENTICATE #{passwd}" )
			get_response()[0].raise
		end
	end
end
