#!/usr/bin/ruby
require 'test/unit'
require 'rtorctl'
require 'yaml'

class ExitPolicyTest < Test::Unit::TestCase
	include RTorCtl
	ExitPolicyLine = ExitPolicy::ExitPolicyLine

	def setup
		@ips = YAML.load_file( "data/ips.yaml" )
		@policies = YAML.load_file( "data/exit_policies.yaml" )
	end

	def test_ip_address
		@ips[:ips].each do |ip, attrs|
			x = IPAddress.new(ip)
			assert_equal( x.to_a, attrs[:parts], "array-like access to IPs" )
			assert_equal(
				[x[0], x[1], x[2], x[3]],
				attrs[:parts],
				"index-based access to IPs"
			)
			assert_equal( x.to_i, attrs[:integer], "integer conversion of IPs" )
			assert_equal( x.to_s, ip, "string conversion of IPs" )

			attrs[:over].each do |netmask, result|
				assert_equal( IPAddress.new(result), x/netmask, "masking of IPs" )
			end
		end

		@ips[:invalid_ips].each do |x|
			assert_raise(NotAnIPError){ IPAddress.new(x) }
		end
	end

	def test_exit_policy_line
		@policies[:lines].each do |line, res|
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
		@policies[:policies].each do |policy, results|
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
