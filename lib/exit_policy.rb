#!/usr/bin/ruby
require 'exceptions'
require 'rubygems'
require 'ip_address'

module RTorCtl
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
