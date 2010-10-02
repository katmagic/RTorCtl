#!/usr/bin/ruby
require 'exit_policy'
require 'time'
require 'set'

module RTorCtl
	class TorVersion
		include Comparable

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

	class Bytes
		def initialize(bytes)
			@i = bytes
		end

		def  b() @i / 1024.0**0 end
		def kb() @i / 1024.0**1 end
		def mb() @i / 1024.0**2 end
		def gb() @i / 1024.0**3 end
		def tb() @i / 1024.0**4 end

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

	RelayInitializer = Struct.new( *(%w<nickname idkey_hash desc_hash
		desc_published ip or_port dir_port flags reported_bandwidth
		measured_bandwidth condensed_exit_policy>.map{|x|x.to_sym}) )

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

		def parse_read_history(l)
			l =~ /^(\d{4}(?:-\d\d){2} \d\d(?::\d\d){2}) \((\d+) s\) ((?:\d+,)*\d+)$/
			i_end = Time.parse($1)
			i_length = $2.to_i
			i_values = $3.split(",").map{|x|x.to_i}.reverse

			values = Hash.new
			intrvl_values.each_with_index do |index, val|
				values[(i_end - i_length*(index+1)) ... (i_end)] = val
			end

			values
		end
		alias :parse_write_history :parse_read_history

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

			@attributes = RelayInitializer.members

			descriptors, @options = parse_descriptor( descriptor )

			descriptors.each do |k, v|
				@attributes << k unless k == :_unknowns

				instance_variable_set( "@#{k}".to_sym, v )

				self.class.class_eval do
					define_method(k) { instance_variable_get("@#{k}".to_sym) }
				end unless respond_to?(k)
			end
		end

		BEGIN_LINE = /^-----BEGIN /
		END_LINE = /^-----END /
		def parse_descriptor( descriptor )
			# Parse descriptors, calling parse_#{option_name}( rest_of_line || data )
			# to derive the parsed values. Return an Array containing a Hash of the
			# option names and parsed values. The _unknowns value is an Array of
			# options which we were unable to parse and used the unparsed value for.
			# In order to facilitate the other parse_* options, we initialize @_tmp to
			# a new Hash when we start and set it to nil when we finish.

			@_tmp = Hash.new
			attributes = {:_unknowns => []}
			options = Array.new

			add_val = Proc.new do |_opt, _data|
				if private_methods.include?("parse_#{_opt}")
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
				if line =~ BEGIN_LINE or recieving_data
					data += line

					if line =~ END_LINE
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

				next if line =~ END_LINE

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

		def get_descriptor()
			getinfo_key = "server/d/#{@desc_hash}"
			@descriptor ||= @rtorctl.getinfo(getinfo_key)
			process_descriptor(@descriptor)
		end

		public

		attr_reader :attributes, :options, *(RelayInitializer.members)

		def inspect
			"#<#{self.class} #{@nickname}@#{@ip}>"
		end

		def initialize( rtorctl, relay_initializer )
			relay_initializer.members.each do |m|
				instance_variable_set( "@#{m}", relay_initializer[m] )
			end

			@rtorctl = rtorctl
			@descriptor = nil
		end

		def method_missing(meth, *args, &proc)
			unless @descriptor
				get_descriptor()
				return send(meth, *args, &proc)
			end

			super
		end
	end

	class Relays
		# RTorCtl::RTorCtl.relays

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
			@rtorctl.getinfo("ns/all").each do |l|
				r = relays[-1] # Ugh. Annoying scope. Listerine ftw!
				case l
					when /^r (\S+) (\S+) (\S+) (\S+ \S+) (\S+) (\S+) (\S+)$/
						r = RelayInitializer.new
						relays << r

						r.nickname = $1
						r.idkey_hash = $2
						r.desc_hash = $3
						r.desc_published = Time.parse("#{$4} UTC")
						r.ip = IPAddress.new($5)
						r.or_port = $6.to_i
						r.dir_port = $7 != "0" ? $7.to_i : nil

					when /^s (.*)$/
						r.flags = $1.split().map{|x|x.to_sym}

					when /^w Bandwidth=(\d+)(?: Measured=(\d+))?$/
						r.reported_bandwidth = $1.to_i
						r.measured_bandwidth = $2 && $2.to_i

					when /^p (accept|reject) (\S+)$/
						x = $1 # This will get reassigned some time before it's used.
						r.condensed_exit_policy = ExitPolicy.new
						$2.split(",").each do |p|
							r.condensed_exit_policy << "#{x} *:#{p}"
						end
						r.condensed_exit_policy << "#{x=='accept'?:reject:x} *:*"
				end
			end

			@relays = relays.map{|r| Relay.new(@rtorctl, r)}
		end

		def [](nickname)
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
