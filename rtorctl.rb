#!/usr/bin/ruby
# RTorCtl presents a Rubyonic interface to Tor's control port.

require 'codes'
require 'quote'
require 'exceptions'
require 'exit_policy'
require 'connection'

module RTorCtl
	class RTorCtl
		def initialize(passwd=:IMPLIED, ctlport=9051)
			if passwd == :IMPLIED
				@passwd = determine_control_password()
			else
				@passwd = passwd
			end
			@ctlport = ctlport

			@connection = Connection.new(@passwd, @ctlport)

			@connection.connect()
			authenticate()
		end

		def determine_control_password
			ENV['TORCTL_PASSWD'] ||
			( open(ENV['TORCTL_PASSWD_FILE']).read() rescue nil ) ||
			(ARGV.grep(/^-passwd=(.*)/) && $1) ||
			(ARGV.grep(/^-passwd_file=(.*)/) && $1) \
			or raise RTorCtlError, "couldn't determine password!"
		end

		def get_basic_response()
			# Get a response like "512 Authentication error" from Tor and return
			# [ <RTorCtl::Code 512>, "Authentication error" ]

			unless @connection.gets() =~ /^(\d+) (.*)$/
				raise NotImplementedError, ""
			end

			[Code.new($1), $2]
		end

		def puts(line)
			@connection.puts(line)
		end

		def authenticate()
			puts( "AUTHENTICATE #{Quote[@passwd]}" )
			get_basic_response()[0].raise
		end
	end
end
