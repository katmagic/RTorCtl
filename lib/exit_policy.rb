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
			@as_array ||= int_to_array(@ip)
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

	class ExitPolicy
		# This class represents a single line in an exit policy.
		class ExitPolicyLine

			REGEXP = /^(accept|reject) ([\d+.*\/]+):(\d+|\*)(?:-(\d+))?$/

			# either :accept or :reject
			attr_reader :acceptance
			# an instance of IPAddress
			attr_reader :ip
			# the Range of ports we affect
			attr_reader :port_range

			def initialize(policy_line)
				policy_line = policy_line.rstrip

				unless REGEXP =~ policy_line
					raise ParsingError,
						"#{policy_line.inspect} is an invalid exit policy line"
				end

				@acceptance = $1.to_sym
				@ip = IPAddress.new( $2 == "*" ? "0.0.0.0/0" : $2 )

				@port_range = case
					when $3 == "*" then (0..65536)
					when $4 then ($3.to_i .. $4.to_i)
					else ($3.to_i .. $3.to_i)
				end
			end

			# Do we affect ip:port?
			def matches?(ip, port)
				@ip === ip and @port_range === port
			end
			# +matches?(*ip_port)+
			def ===(ip_port)
				matches?( *ip_port )
			end

			# Are we equivalent to another exit policy?
			# @param [ExitPolicyLine] other
			def ==(other)
				@acceptance == other.acceptance and
				@ip == other.ip and
				@port_range == other.port_range
			end

			def to_s
				ip = @ip == IPAddress.new("0.0.0.0/0") ? "*" : @ip
				if @port_range.first == @port_range.last
					port_range = @port_range.first
				elsif @port_range == (0..65536)
					port_range = "*"
				else
					port_range = "#{@port_range.begin}-#{@port_range.end}"
				end

				"#{@acceptance} #{ip}:#{port_range}"
			end

			def inspect
				"#<#{self.class}: #{to_s}>"
			end

			def netmask
				ip.netmask
			end
		end

		attr :policies

		def initialize(policy="")
			@policies = policy.map{ |line| ExitPolicyLine.new(line) }
		end

		# Are connections to ip:port accepted?
		def accepts?(ip, port)
			self === [ip, port]
		end

		# Are connections to ip:port rejected?
		def rejects?(ip, port)
			!(self === [ip, port])
		end

		def ==(policy)
			@policies == policy.policies
		end

		# Are connections to the IP and port specified in +ip_port+ accepted?
		# @param [Array<IPAddress, Fixnum>] ip_port something like ["1.4.1.6", 22]
		def ===(ip_port)
			if a = @policies.find{ |pol| pol === ip_port }
				a.acceptance == :accept
			else
				DEFAULT_POLICY === ip_port
			end
		end

		# Insert a new rule +rule+ at position +pos+.
		def insert(pos, rule)
			rule = ExitPolicyLine.new(rule) unless rule.is_a? ExitPolicyLine
			@policies.insert( pos, rule )
		end

		# Delete the rule at position +pos+.
		def delete(pos)
			@policies.delete_at(pos)
		end

		# Append a rule.
		def push(rule)
			insert(-1, rule)
		end

		# Append a rule, returning self.
		def <<(rule)
			push(rule)

			self
		end

		# Remove the last rule.
		def pop()
			delete(-1)
		end

		# Remove the first rule.
		def shift()
			delete(0)
		end

		# Create a rule with the highest precedence.
		def unshift(rule)
			insert(0, rule)
		end

		def to_s
			@policies.join(",")
		end

		def to_a
			@policies
		end

		def inspect()
			"#<#{self.class}: #{self}>"
		end

		DEFAULT_POLICY = self.new([
			"reject *:25",
			"reject *:119",
			"reject *:135-139",
			"reject *:445",
			"reject *:563",
			"reject *:1214",
			"reject *:4661-4666",
			"reject *:6346-6429",
			"reject *:6699",
			"reject *:6881-6999",
			"accept *:*"
		])
	end
end
