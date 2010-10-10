#!/usr/bin/ruby
require 'exit_policy'
require 'time'
require 'set'

module RTorCtl
	# This class allows different Tor versions to be compared.
	class TorVersion
		include Comparable

		# @param [String] version a Tor version, like "0.2.3.0-alpha-dev"
		def initialize(version)
			unless v = version.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)/)
				raise ArgumentError, "invalid version string"
			end

			@versions = v.captures.map{|x| x.to_i}
		end

		def <=>(other)
			base = (to_a + other.to_a).max

			to_i = lambda{ |v| v.to_a.reduce{|x, y| x*base + y} }

			return to_i.call(self) <=> to_i.call(v)
		end

		# @return [Array<Fixnum, Fixnum, Fixnum, Fixnum>] the version numbers as
		#  separate integers
		def to_a
			@versions
		end
	end

	class UnknownOptionError < ParsingError
		attr_reader :option, :line

		def initialize(option, line)
			@option = option
			@line = line

			super( "we don't know about #{option}" )
		end
	end

	# This class represents size in a user friendly way.
	#
	# @example
	#  [141622, 142978, 4723985].map{|x| RTorCtl::Bytes.new(x).to_s}
	#  # ["138.30KB", "139.63KB", "4.51MB"]
	class Bytes
		# @param [Fixnum] bytes
		def initialize(bytes)
			@i = bytes
		end

		def  b() @i / 1024.0**0 end
		def kb() @i / 1024.0**1 end
		def mb() @i / 1024.0**2 end
		def gb() @i / 1024.0**3 end
		def tb() @i / 1024.0**4 end

		# @return [String] a string like "138.30KB" or "4.51MB"
		def to_s
			%w{ tb gb mb kb b }.each do |x|
				if send(x) > 1
					return "%.2f#{x.upcase}" % send(x)
				end
			end

			return "0B"
		end

		def to_i
			@i
		end

		def ==(x)
			@i == x
		end

		def method_missing(meth, *args, &block)
			self.class.new( @i.send(meth, *args, &block) )
		end
	end

=begin
This class represents a relay in the Tor network.

@example
 relay.nickname # "molko"
 relay.address # #<IPAddress: 14.16.22.0>
 relay.or_port # 443
 relay.dir_port # nil
 relay.bandiwdth_average # #<Bytes:0x14029078 @i=968>
 relay.platform # "Windows Vista"
 relay.published # Tue Jan 19 03:14:07 UTC 2038
 relay.fingerprint # :"4E1A97201B80A872DA4847ADF022E456876E73F8"
 relay.hibernating # false
 relay.uptime # 142978
 # ^ THIS IS THE UPTIME AS OF relay.published!!! See relay.online_since for a
 # more informative value.
 relay.exit_policy # #<ExitPolicy: reject *:25,accept *:*>
 relay.family # [<Relay: brian@14.2,9.78>]
 relay.online_since # Sat Oct 09 21:38:01 UTC 2010
=end
	class Relay

		private

		def parse_router(l)
			l =~ /^(\w+) ([\d\.]{7,15}) (\d+) 0 (\d+)$/

			{
				:nickname => $1,
				:address => IPAddress.new($2),
				:or_port => $3 != "0" ? $3.to_i : nil,
				:dir_port => $4 != "0" ? $4.to_i : nil
			}
		end

		def parse_bandwidth(l)
			l =~ /^(\d+) (\d+) (\d+)$/

			{
				:bandwidth_average => Bytes.new($1.to_i),
				:bandwidth_burst => Bytes.new($2.to_i),
				:bandwidth_observed => Bytes.new($3.to_i)
			}
		end

		def parse_platform(l)
			l
		end

		def parse_published(l)
			Time.parse("#{l} UTC")
		end

		def parse_fingerprint(l)
			l.tr(" ", "").to_sym
		end

		def parse_hibernating(l)
			l == "1"
		end

		def parse_uptime(l)
			l.to_i
		end

		def parse_onion_key(data)
			data
		end

		def parse_signing_key(data)
			data
		end

		def parse_accept(l)
			@_ep ||= ExitPolicy.new
			@_ep.push "accept #{l}"

			{ :exit_policy => @_ep }
		end

		def parse_reject(l)
			@_ep ||= ExitPolicy.new
			@_ep.push "reject #{l}"

			{ :exit_policy => @_ep }
		end

		def parse_router_signature(data)
			data
		end

		def parse_contact(l)
			l
		end

		def parse_family(l)
			l.split
		end
		# We have to define a family method separate from its parse method because
		# it uses @rtorctl.relays, which calls Relay.initialize(), which in turn
		# calss our parse_family().
		def family
			@family.map{|f| @rtorctl.relays[f] || InvalidRelay.new(f)}
		end
		public :family

		def parse_history(l)
			l =~ /^(\d{4}(?:-\d\d){2} \d\d(?::\d\d){2}) \((\d+) s\) ((?:\d+,)*\d+)$/
			i_end = Time.parse($1)
			i_length = $2.to_i
			i_values = $3.split(",").map{|x|x.to_i}.reverse

			values = Hash.new
			i_values.each_with_index do |val, index|
				period = (i_end - i_length*(index+1)) ... (i_end - i_length*index)
				values[period] = val
			end

			values
		end
		def parse_read_history(l) { :read_history => parse_history(l) } end
		def parse_write_history(l) { :write_history => parse_history(l) } end

		def parse_eventdns(l)
			l == "1"
		end

		def parse_accept(l)
			@_tmp[:exit_policy] ||= ExitPolicy.new
			@_tmp[:exit_policy].push("accept #{l}")

			{ :exit_policy => @_tmp[:exit_policy] }
		end

		def parse_reject(l)
			@_tmp[:exit_policy] ||= ExitPolicy.new
			@_tmp[:exit_policy].push("reject #{l}")

			{ :exit_policy => @_tmp[:exit_policy] }
		end

		def parse_protocols(l)
			l =~ /^Link ([\d\s]+) Circuit ([\d\s]+)/

			{
				:link_protocols => $1.split().map{|x|x.to_i},
				:circuit_protocols => $2.split().map{|x|x.to_i}
			}
		end

		def parse_extra_info_digest(l)
			l
		end

		def process_descriptor( descriptor )
			# Parse the descriptor, perform conversions, and set all the appropriate
			# values.

			@attributes = []

			descriptors, @options = parse_descriptor( descriptor )

			descriptors.each do |k, v|
				@attributes << k unless k == :_unknowns

				instance_variable_set( "@#{k}".to_sym, v )

				self.class.class_eval do
					define_method(k) { instance_variable_get("@#{k}".to_sym) }
				end unless respond_to?(k)
			end
		end

		# Set this programatically so YARD won't pick them up.
		const_set(:PARSERS, private_instance_methods.grep(/^parse_(.*)/){$1.to_sym})


=begin
Parse descriptors, calling +parse_#{option_name}( rest_of_line || data )+ to
derive the parsed values. Return an Array containing a Hash of the option names
and parsed values. The _unknowns value is an Array of options which we were
unable to parse and used the unparsed value for. In order to facilitate the
other parse_* options, we initialize @_tmp to a new Hash when we start and set
it to nil when we finish.
=end
		def parse_descriptor( descriptor )
			@_tmp = Hash.new
			attributes = {:_unknowns => []}
			options = Array.new

			add_val = Proc.new do |_opt, _data|
				if PARSERS.include?(_opt.to_sym)
					resp = send("parse_#{_opt}", _data)
				else
					warn "unrecognized option #{_opt}"
					attributes[:_unknowns] << _opt.to_sym
					resp = _data
				end

				if resp.is_a? Hash
					attributes.update(resp)
				else
					attributes[_opt] = resp
				end
			end

			recieving_data = false
			data = ""
			opt = nil
			is_opt = false
			descriptor.each do |line|
				if line =~ /^-{5}BEGIN / or recieving_data
					data += line

					if line =~ /^-{5}END /
						recieving_data = false
					else
						recieving_data = true
						next
					end
				end

				if opt
					if is_opt and data == "" # this is a boolean option
						options << opt.to_sym
					else
						add_val.call(opt, data)
					end

					data = ""
					opt = nil
					is_opt = false
				end

				next if line =~ /^-{5}END /

				line =~ /^(opt )?([\w\-]+)(?: (.*?))?\r?$/
				is_opt, opt, data = $~.captures
				opt.tr!("-", "_")
				is_opt = !!is_opt
				data = data.to_s
			end

			if is_opt and opt and data == ""
				options << opt.to_sym
			elsif opt
				add_val.call(opt, data)
			end

			@_tmp = nil
			[attributes, options]
		end

		public

		# an Array of attributes has the descriptor defined
		attr_reader :attributes
		# an Array of symbols with the various options a router has set
		attr_reader :options
		# a String containing the actual descriptor
		attr_reader :descriptor

		def inspect
			"#<#{self.class} #{@nickname}@#{@address}>"
		end

		# @param [RTorCtl] rtorctl an RTorCtl instance we can query for extra info
		# @param [Array] descriptor the lines of the relay's descriptor.
		def initialize(rtorctl, descriptor)
			@rtorctl = rtorctl
			@descriptor = descriptor
			process_descriptor(@descriptor)
		end

		# When did this relay come online?
		# @return [Time]
		def online_since
			@published - @uptime
		end

		# Does this relay have the AllowSingleHopExits flag set to 1?
		def allows_single_hop_exits?
			@options.include? :allow_single_hop_exits
		end

		# Is this relay a hidden service directory?
		def hidden_service_dir?
			@options.include? :hidden_service_dir
		end

		# Is this relay a directory cache that provides extra-info?
		def caches_extra_info?
			@options.include? :caches_extra_info
		end
	end

	# This class represents a relay that's referenced but doesn't actually exist.
	class InvalidRelay
		def initialize(nickname)
			@nickname = nickname
		end

		def inspect
			"#<#{self.class} #{@nickname}>"
		end
	end

	class Relays
		# RTorCtl::RTorCtl.relays
		# Warning: This is *very* slow at the moment.

		include Enumerable

		def initialize(rtorctl)
			@rtorctl = rtorctl
		end

		def each(&proc)
			reload() unless @relays
			@relays.each(&proc)
		end

		def reload()
			# Repopulate our list of relays.

			relays = []
			# See doc/spec/dir-spec-v2.txt in Tor's source.
			@rtorctl.getinfo("desc/all-recent").each do |l|
				if l =~ /^router /
					relays << [l]
				else
					relays[-1] << l
				end
			end

			@relays = relays.map{|r| Relay.new(@rtorctl, r)}
		end

		def [](nickname)
			# Find a relay by nickname, or return nil.

			self.find{|r| r.nickname == nickname.to_s}
		end

		def grep(regexp, &block)
			# Find all relays whose nickname's match a given regular expression. If
			# the optional _block_ is supplied, each matching element is passed to it,
			# and the block's result is stored in the output array.

			matches = find_all{ |r| r.nickname =~ regexp }

			block ? matches.map{|r| block[r] } : matches
		end
	end
end
