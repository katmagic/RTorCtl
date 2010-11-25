#!/usr/bin/ruby
require 'getinfo'
require 'relay'
require 'time'
require 'exit_policy'
require 'object_proxies'

module RTorCtl
	class AddressMapping
		attr_reader :type, :from, :to, :expiry

		def initialize(type, from, to, expiry=nil)
			@type = type.to_sym
			@from = from
			@to = IPAddress.is_an_ip?(to) ? IPAddress.new(to) : to
			@expiry = Time.parse(expiry) if expiry
		end

		# Will the mapping have expired on _date_?
		# @param [Time] date
		def expired_on?(date)
			date >= @expiry
		end

		def to_s
			"#{@from} -> #{@to}"
		end

		def inspect
			"#<#{self.class} #{self}>"
		end
	end

	class Stream
		attr_accessor :status
		attr_reader :stream_id, :dest, :circuit_id

		# Subclassing AddrPort outright causes problems if it's redefined.
		AddrPort = Struct.new(:addr, :port)
		class AddrPort
			def to_s
				"#{addr}:#{port}"
			end

			def inspect
				to_s
			end
		end

		def initialize(rtorctl, stream_id, stream_status, circuit_id, dest)
			@rtorctl = rtorctl
			@stream_id = stream_id.to_sym
			@stream_status = stream_status.to_sym
			@circuit_id = circuit_id.to_sym

			@dest = AddrPort.new(*dest.split(":", 2)).tap do |d|
				d.addr = IPAddress.is_an_ip?(d.addr) ? IPAddress.new(d.addr) : d.addr
				d.port = d.port.to_i

				m = @rtorctl.mappings.find{ |m| d.addr == m.to }
				d.addr = m if m
			end
		end

		def inspect
			"#<#{self.class}: #{@dest}>"
		end

		def circuit
			@circuit ||= @rtorctl.circuits.find{|c|c.circuit_id == @circuit_id}
		end
	end

	class Circuit
		attr_reader :circuit_id, :path
		attr_writer :status

		def initialize(rtorctl, circuit_id, status, path=[])
			@rtorctl = rtorctl
			@circuit_id = circuit_id.to_sym
			@status = status
			@path = Array.new

			path.each do |p|
				_extend(p)
			end
		end

		def inspect
			path = @path.map{|p| p.nickname}
			"#<#{self.class}:#{@id} #{@status} #{path.join(",")}>"
		end

		# @return [Array<*Stream>] an Array of Streams associated with the circuit
		def streams
			@rtorctl.streams.values.find_all{|s| s.circuit_id == @circuit_id}
		end

		private

		# Add a relay to our internal representation of our path. This *does not*
		# issue any commands to Tor.
		def _extend(relay)
			if relay =~ /^\$(.*)/
				@path << DelayedResult.new{
					@rtorctl.relays.find{|r| r.fingerprint == $1.to_sym}
				}
			else
				@path << DelayedResult.new{ @rtorctl.relays[relay] }
			end
		end
	end

	class RTorCtl
		# Get the address mappings Tor has. These are similar to cached DNS entries.
		#
		# @return [Array<*AddressMapping>] an Array of AddressMapping instances
		#                                  that _may_ be indexed via 'from' values
		def mappings
			# Address mappings look something like
			# 'upload.wikimedia.org 208.80.152.3 "2010-11-11 03:34:19"'

			res = [:config, :cache, :control].map{ |mapping_type|
				getinfo("address-mappings/#{mapping_type}").map{ |mapping|
					AddressMapping.new( mapping_type, *mapping.split(" ", 3) )
				}
			}.flatten

			# :nodoc:
			# Allow the results to be accessed by name.
			def res.[](key)
				key.is_a?(String) ? find{|x| x.from == key} : fetch(key, nil)
			end

			res
		end

		# What streams has Tor opened?
		# @return [Array<*Stream>] an Array of Stream instances that _may_ be
		#                          indexed via the host or IP they exit to. If
		#                          multiple streams exit to an IP, the result of the
		#                          lookup will be an Array.
		#
		# @example
		#  tor.streams # [#<Stream: a.com:80>, #<Stream: a.com:443>,
		#              #  #<Stream: b.com:80>]
		#  tor.streams["a.com"] # [#<Stream: a.com:80>, #<Stream: a.com:443>]
		#  tor.streams["b.com"] # #<Stream: b.com:80>
		#  tor.streams[0]       # #<Stream: a.com:80>
		def streams
			r = getinfo("stream-status").map{ |l| Stream.new(self, *l.split()[0..3]) }

			def r.[](key)
				if key.is_a?(String)
					res = find_all{|x| x.dest[0] == key}
					res.length > 1 ? res : res[0]
				else
					fetch(key, nil)
				end
			end

			r
		end

		def circuits
			getinfo("circuit-status").map{ |l|
				id, status, path = parse_CIRC_event(l, [], {})[0..2]
				Circuit.new(self, id, status, path)
			}
		end
	end
end
