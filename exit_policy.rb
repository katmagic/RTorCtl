#!/usr/bin/ruby
require 'exceptions'

module RTorCtl
	class NotAnIPError < RTorCtlError
		def initialize(not_an_ip)
			super("#{not_an_ip.inspect} isn't a valid IP address")
		end
	end

	class IPAddress
		# ip = IPAddress.new("86.75.30.9") # <IPAddress: 86.75.30.9/32>
		# ip.to_i # 2130706434
		# ip.to_s # "86.75.30.9"
		# ip/8 # <IPAddress: 86.0.0.0/32>
		# (ip/8).to_s # "86.0.0.0/32"
		# (ip/8/32).to_s

		attr_reader :netmask

		def netmask=(val)
			@ip = mask(@ip, val)
			@netmask = val
		end

		def initialize(ip)
			@ip, nmask = any_to_int_and_netmask(ip)

			self.netmask = nmask
		end

		def [](index)
			unless (0..3) === index
				raise ArgumentError, "there are four parts to an IP address"
			end

			to_a[index]
		end

		def []=(index, val)
			if not (0..3).include? index
				raise ArgumentError, "there are four parts to an IP address"
			elsif not (0..256).include? val
				raise ArgumentError, "each of the IP parts is between 0 and 256"
			end

			ip_as_array = to_a
			ip_as_array[index] = val
			@ip, @netmask = any_to_int_and_netmask(ip_as_array)

			val
		end

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

		def /(nmask)
			self.class.new(self).tap{|x| x.netmask = nmask}
		end

		def ==(ip)
			ip = self.class.new(ip) unless ip.is_a? self.class

			ip.to_i == to_i and ip.netmask == @netmask
		end

		def ===(ip)
			self == ( self.class.new(ip) / @netmask )
		end

		private
		def mask(ip_int, nmask)
			(ip_int >> (32 - nmask)) << (32 - nmask)
		end

		def any_to_int_and_netmask(ip)
			# any_to_int_and_netmask("127.0.0.1/8") # 2130706432, 8

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

		def array_to_int(array)
			unless array.all?{ |i| (0..256) === i } and array.length == 4
				raise NotAnIPError.new(array)
			end

			return array.reduce(0){ |x, y| x*256 + y }
		end

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
		class ExitPolicyLine
			# epl = ExitPolicyLine.new("accept 1.2.3.4/8:666-1337")
			# epl.acceptance # :accept
			# epl.ip # #<IPAddress: 1.0.0.0/8>
			# epl.netmask # 8
			# epl.port_range # (666..1337)

			REGEXP = /^(accept|reject) ([\d+.*\/]+):(\d+|\*)(?:-(\d+))?$/

			attr_reader :acceptance, :ip, :netmask, :port_range

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

			def matches?(ip, port)
				@ip === ip and @port_range.include?(port)
			end
			def ===(ip_port)
				matches?( *ip_port )
			end

			def ==(other)
				@acceptance == other.acceptance and
				@ip == other.ip and
				@port_range == other.port_range
			end

			def to_s
				"#{@acceptance} #{@ip}:#{@port_range.begin}-#{@port_range.end}"
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

		def accepts?(ip, port)
			@policies.find{ |pol| pol.matches?(ip, port) }.acceptance == :accept
		end

		def rejects?(ip, port)
			@policies.find{ |pol| pol.matches?(ip, port) }.acceptance == :reject
		end

		def ==(policy)
			@policies == policy.policies
		end

		def ===(ip_port)
			if policy = @policies.find{ |pol| pol === ip_port }
				return pol.acceptance == :accept
			else
				raise RTorCtlError, "we've not decided whether to allow " +
					ip_port.join(":")
			end
		end

		def insert(pos, rule)
			rule = ExitPolicyLine.new(rule) unless rule.is_a? ExitPolicyLine
			@policies.insert( pos, rule )
		end

		def delete(pos)
			@policies.delete_at(pos)
		end

		def push(rule)
			insert(-1, rule)
		end

		def <<(rule)
			push(rule)

			self
		end

		def pop()
			delete(-1)
		end

		def shift()
			delete(0)
		end

		def unshift(rule)
			insert(0, rule)
		end

		def to_s
			@policies.join("\n")
		end

		def inspect()
			"#<#{self.class}:\n#{self}\n>"
		end
	end
end
