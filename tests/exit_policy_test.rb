#!/usr/bin/ruby
require 'test/unit'
require 'exit_policy'

class ExitPolicyTest < Test::Unit::TestCase
	EP = RTorCtl::ExitPolicy

	Rejecter = EP.new("reject *:*")
	Accepter = EP.new("accept *:*")

	IP_PORT_PAIRS = %w{
		1.1.1.1:15
		15.15.15.15:8888
		0.0.0.0:1
		192.168.1.1:515
		210.51.99.1:61350
		17.1.5.101:33
		17.1.10.111:109
	}.map{ |x|
		ip, port = x.split(':')
		port = port.to_i
		[ip, port]
	}

	# The values denote which entries from IP_PORT_PAIRS will be accepted by a
	# ruleset.
	RULESETS = Hash[ {
		"reject *:*" => [],
		"accept *:*" => [0,1,2,3,4,5,6],
		"accept *:*, reject *:*" => [0,1,2,3,4,5,6],
		"reject *:*, accept *:*" => [],
		"accept 17.1.0.0/16:20-50, reject *:*" => [5],
		"reject 17.1.5.101:*, accept 17.1.0.0/16:20-200, reject *:*" => [6],
		"reject 210.0.0.0/9:60000-65535, accept *:*, reject *:*" => [0,1,2,3,5,6]
	}.map{|k, v| [k.split(", "), v]} ]

	def test_rules
		RULESETS.each do |ruleset, accepted_indices|
			policy = EP.new(ruleset)

			rejected_indices = (0...IP_PORT_PAIRS.length).to_a - accepted_indices
			accepted = accepted_indices.map{|i| IP_PORT_PAIRS[i]} # RY
			rejected = rejected_indices.map{|i| IP_PORT_PAIRS[i]} # RY

			ip, port = nil, nil # Allow ip and port to be accessed in msg.
			msg = lambda{|s| "#{policy} should #{s} #{ip}:#{port}"}

			accepted.each do |ip, port|
				assert( policy.accepts?(ip, port), msg["accept"] )
				assert( !policy.rejects?(ip, port), msg["not reject"] )
			end

			rejected.each do |ip, port|
				assert( policy.rejects?(ip, port), msg["reject"] )
				assert( !policy.accepts?(ip, port), msg["not accept"] )
			end
		end
	end

	INVALID_LINES = "okel
okachoobee
accept 515.10.15.88:15
reject *:12.50.11.5/12
                                            *
kgoledm99*8w9ois--\x00
	r".map{|x| x.strip}

	def test_the_rejection_of_invalid_lines
		INVALID_LINES.each do |il|
			assert_raises(
				RTorCtl::ParsingError,
				"#{il.inspect} is an invalid policy line"
			) { EP.new(il) }
		end
	end
end
