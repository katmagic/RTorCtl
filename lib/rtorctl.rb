#!/usr/bin/env ruby
require 'bundler/setup'
require 'socket'
require 'citrus'

# Load one of our Citrus grammars.
def require_grammar(grammar)
	Citrus.load( File.join($rtorctl_grammar_dir, grammar) )
end
$rtorctl_grammar_dir = File.join(
	File.dirname(File.absolute_path(File.dirname(__FILE__))), 'grammars' )

# Define the RTorCtl namespace.
module RTorCtl; end

require_grammar 'misc_data'

require_relative 'quoting'
require_relative 'errors'
require_relative 'configuration'
require_relative 'controller_reply'

module RTorCtl
	class RTorCtl
		include Quoting
		include Configuration

		def initialize(passwd=ENV['TOR_CONTROL_PASSWD'],
		               port=(ENV['TOR_CONTROL_PORT'] || 9050).to_i,
		               host='127.0.0.1')
			@connection = TCPSocket.new(host, port)
			@passwd = passwd

			# class-local lock
			@clock = Mutex.new

			@reply_queue = Queue.new
			@async_queue = Queue.new

			start_response_queuing_thread()

			unless authenticate(@passwd)
				raise AuthenticationError
			end
		end

		# Authenticate with passwd to the controller. We return true if
		# authentication succeeds, and false if it fails.
		def authenticate(passwd)
			res = sendrecv(%Q<AUTHENTICATE #{quote(passwd)}>)

			case res.status_code
				when 250 then true # success
				when 515 then false # failure
				else raise(ControllerError, res)
			end
		end

		# Send a synchronous command to the controller and receive a
		# (Generic)Response.
		def sendrecv(cmd)
			@clock.synchronize do
				writeline(cmd)
				@reply_queue.pop()
			end
		end

		private

		# Send str + CRLF to the controller.
		def writeline(str)
			puts("writing #{(str+"\r\n").inspect}") if $DEBUG
			@connection.write(str + "\r\n")
		end

		# Start a thread that listens for the controller's responses and pushes them
		# to @reply_queue and @async_queue.
		def start_response_queuing_thread
			@response_queuing_thread = Thread.new do
				loop do
					r = ControllerReply.parse(get_response()).value

					# Integer division rounds down, so this is equivalent to getting just
					# the third digit. (Status codes only have 3 digits.)
					if (r.status_code / 100) == 6
						@async_queue.push(r)
					else
						@reply_queue.push(r)
					end
				end
			end
		end

		# Block until we get a single response from the controller, then return it.
		# THIS SHOULD ONLY BE CALLED FROM start_response_queuing_thread().
		# Everything else should use the queues.
		def get_response()
			data = ""

			while true
				data += @connection.read(4)

				case data[-1]
					when ' '
						data += @connection.gets("\r\n")
						puts("received #{data.inspect}") if $DEBUG
						return data

					when '-'
						data += @connection.gets("\r\n")

					when '+'
						data += @connection.gets("\r\n.\r\n")
				end
			end

			data
		end
	end
end

