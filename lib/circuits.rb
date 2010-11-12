#!/usr/bin/ruby
require 'getinfo'
require 'relay'
require 'time'
require 'exit_policy'

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

		def initialize(stream_id, stream_status, circuit_id, dest)
			@stream_id = stream_id.to_sym
			@stream_status = stream_status.to_sym
			@circuit_id = circuit_id.to_sym

			@dest = dest.split(":", 2)
				@dest[0] =
					IPAddress.is_an_ip?(@dest[0]) ? IPAddress.new(@dest[0]) : @dest[0]
				@dest[1] = @dest[1].to_i
		end
	end

	class RTorCtl
		# Get the address mappings Tor has. These are similar to cached DNS entries.
		def mappings
			# Address mappings look something like
			# 'upload.wikimedia.org 208.80.152.3 "2010-11-11 03:34:19"'

			res = [:config, :cache, :control].map{ |mapping_type|
				getinfo("address-mappings/#{mapping_type}").map{ |mapping|
					AddressMapping.new( mapping_type, *mapping.split(" ", 3) )
				}
			}.flatten

			# Allow the results to be accessed by name.
			def res.[](key)
				key.is_a?(String) ? find{|x| x.from == key} : fetch(key, nil)
			end

			res
		end

		# What streams has Tor opened?
		def streams
			getinfo("stream-status").map{ |l| Stream.new(*l.split()[0..3]) }
		end
	end
end
