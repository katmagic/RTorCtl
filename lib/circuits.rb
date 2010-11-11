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

	class RTorCtl
		# Get the address mappings Tor has. These are similar to cached DNS entries.
		def mappings
			# Address mappings look something like
			# 'upload.wikimedia.org 208.80.152.3 "2010-11-11 03:34:19"'
			[:config, :cache, :control].map{ |mapping_type|
				getinfo("address-mappings/#{mapping_type}").map{ |mapping|
					AddressMapping.new( mapping_type, *mapping.split(" ", 3) )
				}
			}.flatten
		end
	end
end
