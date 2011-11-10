#!/usr/bin/env ruby
require_grammar 'v3consensus'

module RTorCtl
	# This represents an exit policy as given in the v3 network consensus.
	class MicroPolicy
		# If we are :accept, then all ports *other* than the ones specified in our
		# policy our *rejected*. If we are :reject, the opposite is true.
		attr_reader :acceptance
		# Thse are port ranges specified in the policy.
		attr_reader :ranges
		# These are the individual ports specified in the policy.
		attr_reader :ports

		# acceptance is either :accept or :reject. ranges are Range or Fixnum
		# instances describing which ports are accepted or rejected.
		def initialize(acceptance, *ranges)
			unless [:accept, :reject].include?(acceptance)
				raise ArgumentError, "acceptance is invalid"
			end

			@acceptance = acceptance
			@ranges = ranges.find_all{|_| _.is_a?(Range)}.freeze
			@ports = ranges.find_all{|_| _.is_a?(Fixnum)}.freeze
		end

		# Does this micropolicy accept port?
		def accepts?(port)
			if (@ranges + @ports).find{|rop| rop === port}
				@acceptance == :accept
			else
				@acceptance == :reject
			end
		end

		# Does this micropolicy reject port?
		def rejects?(port)
			!accepts?(port)
		end
	end

	# We cause an error if we're re-load()ed.
	remove_const(:V3ConsensusStatement) if defined?(V3ConsensusStatement)
	class V3ConsensusStatement < Struct.new(:nick, :key_hash, :desc_hash,
	                                        :published, :ip, :or_port, :dir_port,
	                                        :version, :reported_bw, :measured_bw,
	                                        :micropolicy, :flags)
	end

	module V3Consensus
		# Get the version 3 consensus entry of relay, or a list of all version 3
		# consensus entries. relay is either a fingerprint, beginning with '$', or
		# a nick. We raise KeyError if the relay can't be found, or the nick isn't
		# unique.
		def get_v3_consensus(relay=nil)
			key = case relay
				when nil then "ns/all"
				when /^\$/ then "ns/id/#{relay[1..-1]}"
				else "ns/name/#{relay}"
			end

			if key == "ns/all"
				V3ConsensusGrammar.parse(getinfo(key)).value
			else
				V3ConsensusGrammar.rule(:v3_consensus_statement).parse(getinfo(key))\
				                  .value
			end
		end
	end
end
