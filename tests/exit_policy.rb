#!/usr/bin/ruby
require 'exit_policy'
require 'test/unit'

class ExitPolicyTest < Test::Unit::TestCase
	include RTorCtl
	ExitPolicyLine = ExitPolicy::ExitPolicyLine

	def test_any_to_ip_netmask
		ip = IPAddress.allocate

		{
			[47, 23, 98, 5] => [0x2f176205, 32],
			0x2f176205 => [0x2f176205, 32],
			"47.23.98.5" => [0x2f176205, 32],
			IPAddress.new("47.23.98.5") => [0x2f176205, 32],
			"47.23.98.5/32" => [0x2f176205, 32],
			"47.23.98.5/8" => [0x2f176205, 8],
			IPAddress.new("47.23.98.5/32") => [0x2f176205, 32],
			IPAddress.new("47.23.98.5/8") => [0x2f000000, 8]
		}.each do |input, output|
			assert_equal(
				output,
				ip.send(:any_to_int_and_netmask, input),
				"any_to_int_and_netmask(#{input.inspect}) should be #{output.inspect}"
			)
		end
	end

	def test_ip_address
		ip = IPAddress.new("47.23.98.5")

		assert_equal(47, ip[0])
		assert_equal(23, ip[1])
		assert_equal(98, ip[2])
		assert_equal( 5, ip[3])
		assert_equal(
			IPAddress.new("36.23.98.5"), IPAddress.new(ip).tap{|y| y[0] = 36}
		)
		assert_equal( [47, 23, 98, 5], ip.to_a )

		assert_equal(0x2f176205, ip.to_i)
		assert_equal("47.23.98.5", ip.to_s)
		assert_equal( ip, IPAddress.new(ip) )
		assert_equal( ip/8, IPAddress.new("47.0.0.0/8") )
		assert_equal( "<#{ip.class.name}: 47.23.98.5>", ip.inspect )
		assert_equal( "<#{ip.class.name}: 47.0.0.0/8>", (ip/8).inspect )

		["435425", :erefd, nil, "1.4.2.978"].each do |x|
			assert_raise(NotAnIPError){ IPAddress.new(x) }
		end
	end

	def test_exit_policy_line
		lines = {
			"accept 94.236.11.19:36" => {
				:acceptance => :accept,
				:ip => IPAddress.new("94.236.11.19"),
				:netmask => 32,
				:port_range => (36..36)
			},
			"accept 94.236.11.19:36-1416" => {
				:acceptance => :accept,
				:ip => IPAddress.new("94.236.11.19"),
				:netmask => 32,
				:port_range => (36..1416)
			},
			"reject 94.236.11.19/16:36" => {
				:acceptance => :reject,
				:ip => IPAddress.new("94.236.11.19")/16,
				:netmask => 16,
				:port_range => (36..36)
			},
			"reject 94.236.11.19:*" => {
				:acceptance => :reject,
				:ip => IPAddress.new("94.236.11.19"),
				:netmask => 32,
				:port_range => (0..65536)
			},
			"reject *:*" => {
				:acceptance => :reject,
				:ip => IPAddress.new("0.0.0.0")/0,
				:netmask => 0,
				:port_range => (0..65536)
			}
		}

		lines.each do |line, res|
			epl = ExitPolicyLine.new(line)

			res.each do |k, v|
				assert_equal( v, epl.send(k), "#{line.inspect}'s #{k} is #{v}" )
			end
		end

		line = ExitPolicyLine.new("reject 10.10.10.0/24:100-1024")
		assert( line.matches?( '10.10.10.10', 150 ) )
		assert( line === ['10.10.10.15', 1024] )
		assert_equal( "reject 10.10.10.0/24:100-1024", line.to_s )
	end

	def test_exit_policy
		{
"
accept *:*
reject *:*
" => {
	:accepts => "127.0.0.1:9050 14.16.22.36:1429 7.8.0.0:1114",
	:rejects => ""
},
"
accept 127.0.0.1:9051
reject *:9051
accept *:*
" => {
	:accepts => "127.0.0.1:9051 10.0.0.1:12 14.16.22.36:14",
	:rejects => "0.0.0.0:9051 1.1.1.1:9051 10.10.10.10:9051"
}
}.each do |policy, results|
			p = ExitPolicy.new(policy.strip)
			results.each do |k, v|
				results[k] = v.split.map{|x|x.split(":")}.each{|x| x[1] = x[1].to_i}
			end

			results[:accepts].each do |host, port|
				assert(
					p.accepts?(host, port),
					"#{p.inspect} should accept #{host}:#{port}"
				)
			end

			results[:rejects].each do |host, port|
				assert(
					p.rejects?(host, port),
					"#{p.inspect} should reject #{host}:#{port}"
				)
			end
		end

		ep = ExitPolicy.new
		[ "accept 127.0.0.1:9051", "reject *:9051", "accept *:*" ].each do |x|
			ep << x
		end

		assert ep.accepts?('127.0.0.1', 9051)
		assert ep.accepts?('10.0.0.1', 12)
		assert ep.accepts?('14.16.22.34', 14)
		assert ep.rejects?('0.0.0.0', 9051)
		assert ep.rejects?('1.1.1.1', 9051)
		assert ep.rejects?('10.10.10.10', 9051)
	end
end
