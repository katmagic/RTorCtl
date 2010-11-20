#!/usr/bin/ruby
# RTorCtl presents a Rubyonic interface to Tor's control port.

require 'codes'
require 'quote'
require 'exceptions'
require 'exit_policy'
require 'connection'
require 'parse_response'
require 'circuits'
require 'getinfo'
require 'relay'
require 'events'
require 'thread'

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

			@responses = Queue.new
			@response_parsing_thread = Thread.new{ response_parser_loop() }

			authenticate()

			@relays = Relays.new(self)
		end

		# Automagically determine our controller's password.
		def determine_control_password
			return case
				when !ARGV.grep(/^-passwd=(.*)/).empty? then $1
				when !ARGV.grep(/^-passwd_file=(.*)/).empty? then open($1).read()
				when _=ENV['TORCTL_PASSWD'] then _
				when _=ENV['TORCTL_PASSWD_FILE'] then _
				when (File.readable?("/etc/tor/torrc") and \
					!(open("/etc/tor/torrc").grep(/^CookieAuthFile (\S+)/).empty?) and \
					File.readable?($1)) \
						then open($1).read()
				when STDOUT.tty? and STDIN.tty?
					# If all else fails, try asking.

					require 'highline/import'
					return ask("Tor controller password: "){|x| x.echo = "*"}
				else
					raise RTorCtlError, "couldn't determine password!"
					nil # We need this so we won't warn about a useless assignment.
			end
		end

		# Send a signal +sig+ to Tor.
		# @example Put new connections on new circuits.
		#  signal(:NEWNYM)
		def signal(sig)
			@connection.puts("SIGNAL #{sig}")
			get_response()[0].raise()
		end

		def inspect
			to_s
		end

		private

		# Authenticate to the controller.
		def authenticate()
			@connection.puts( "AUTHENTICATE #{encode_password(@passwd)}" )
			get_response()[0].raise
		end

		# Change a password to its hexadecimal representation.
		# @example
		#  encode_password("fag hag whore") # "666167206861672077686F7265"
		def encode_password(passwd)
			passwd.bytes.map{|x| "%02X" % x}.join
		end
	end
end
