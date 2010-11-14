#!/usr/bin/ruby
require 'exceptions'

module RTorCtl
	class NotAnIPError < RTorCtlError
		def initialize(not_an_ip)
			super("#{not_an_ip.inspect} isn't a valid IP address")
		end
	end

	# This class represents an IP address.
	class IPAddress
		# Things that match this are (mostly) IPs.
		IP_REGEXP = /^(?:\d{1,3}\.){3}\d{1,3}$/

		# Is _addr_ a string representation of an IP (without a netmask)?
		def self.is_an_ip?(addr)
			!!( IP_REGEXP =~ addr and addr.split(".").all?{|x| x.to_i < 256} )
		end

		# our netmask
		attr_reader :netmask

		# Set our netmask to _val_.
		def netmask=(val)
			@ip = mask(@ip, val)
			@netmask = val
		end

		# @overload new(ip)
		#  @param [String] ip an IP like "12.4.97.8"
		# @overload new(ip)
		#  @param [String] ip an IP like "12.4.97.0/24"
		# @overload new(ip)
		#  @param [String] ip an IP like [12, 4, 97, 8]
		# @overload new(ip)
		#  @param [IPAddress] ip another IPAddress instance
		# @overload new(ip)
		#  @param [Fixnum] ip an IP like (12*256**3 + 4*256**2 + 97*256 + 8)
		def initialize(ip)
			@ip, nmask = any_to_int_and_netmask(ip)

			self.netmask = nmask
		end

		# Get our _indx_th quad.
		# @example
		#  IPAddress.new("12.4.97.8")[1] #=> 4
		def [](index)
			unless (0..3) === index
				raise ArgumentError, "there are four parts to an IP address"
			end

			to_a[index]
		end

		# Set our _index_th quad to the integer _val_.
		# @example
		#  ip = IPAddress.new("12.4.97.0")
		#  ip[3] = 8
		#  ip #=> #<IPAddress: 12.4.97.8>
		def []=(index, val)
			if not (0..3) === index
				raise ArgumentError, "there are four parts to an IP address"
			elsif not (0..256) === val
				raise ArgumentError, "each of the IP parts is between 0 and 256"
			end

			ip_as_array = to_a
			ip_as_array[index] = val
			@ip, @netmask = any_to_int_and_netmask(ip_as_array)

			val
		end

		# our quads
		def to_a
			int_to_array(@ip)
		end

		def to_s
			to_a.join(".") + (@netmask == 32 ? "" : "/#{@netmask}")
		end

		def to_i
			@ip
		end

		def inspect
			"#<#{self.class}: #{self}>"
		end

		# Return a new IPAddress instance with a netmask of _nmask_ with an IP the
		# same as ours.
		# @example
		#  ip = IPAddress.new("12.4.97.8") / 24 #=> #<IPAddress: 12.4.97.0/24>
		def /(nmask)
			self.class.new(self).tap{|x| x.netmask = nmask}
		end

		def ==(ip)
			ip = self.class.new(ip) unless ip.is_a? self.class

			ip.to_i == to_i and ip.netmask == @netmask
		end

		# Is _ip_ in our IP range?
		def ===(ip)
			self == ( self.class.new(ip) / @netmask )
		end

		private
		def mask(ip_int, nmask)
			(ip_int >> (32 - nmask)) << (32 - nmask)
		end

		# Convert an IP address of any of the forms supported by IPAddress#new() to
		# a Fixnum (also described there) and a netmask.
		# @return [Fixnum, Fixnum] something like [201613576, 32]
		def any_to_int_and_netmask(ip)
			case ip
				when /^((?:\d+\.){3}\d+)(?:\/(\d+))?$/
					m = $~
					int_ip = array_to_int(m[1].split(".").map{|x| x.to_i})
					nmask = (m[2] || 32).to_i

					return int_ip, nmask

				when Array
					return array_to_int(ip), 32

				when Integer
					return ip, 32

				when self.class
					return ip.to_i, ip.netmask

				else
					raise NotAnIPError.new(ip)
			end
		end

		# Turn an Array representation of an IP address _array_ to an equivalent
		# Fixnum representation.
		# @param [Array] array an Array like [12, 4, 97, 8]
		# @return [Fixnum] array.reduce{ |x, y| x*256 + y }
		def array_to_int(array)
			unless array.all?{ |i| (0..256) === i } and array.length == 4
				raise NotAnIPError.new(array)
			end

			return array.reduce{ |x, y| x*256 + y }
		end

		# Turn a Fixnum representation of an IP address _ip_int_ to its Array
		# equivalent.
		# @param [Fixnum] ip_int something like 201613576
		# @return [Array] something like [12, 4, 97, 8]
		def int_to_array(ip_int)
			ip_array = Array.new

			4.times do
				ip_array.unshift( ip_int % 256 )
				ip_int /= 256
			end

			ip_array
		end
	end
end
