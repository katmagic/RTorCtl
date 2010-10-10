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
	# Return an instance of RTorCtl (the class).
	def self.new
		RTorCtl.new
	end

	# This is the class that allows one to control Tor.
	class RTorCtl
		# a +Relays+ instance
		attr_reader :relays
		# a +Connection+ instance
		attr_reader :connection

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

		# Automagically determine our controller's password.
		def determine_control_password
			ENV['TORCTL_PASSWD'] ||
			( open(ENV['TORCTL_PASSWD_FILE']).read() rescue nil ) ||
			(ARGV.grep(/^-passwd=(.*)/) && $1) ||
			(ARGV.grep(/^-passwd_file=(.*)/) && $1) \
			or raise RTorCtlError, "couldn't determine password!"
		end

		# Send a signal +sig+ to Tor.
		# @example Put new connections on new circuits.
		#  signal(:NEWNYM)
		def signal(sig)
			@connection.puts("SIGNAL #{sig}")
			get_response()[0].raise()
		end

		private

		# Authenticate to the controller.
		def authenticate()
			passwd = @passwd.bytes.map{|x| "%02X" % x}.join
			@connection.puts( "AUTHENTICATE #{passwd}" )
			get_response()[0].raise
		end
	end
end
