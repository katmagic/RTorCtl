#!/usr/bin/ruby
require 'set'
require 'object_proxies'

module RTorCtl
	class RTorCtl
		# Modifying or assigning events _will_ cause _set_events to be called with
		# events.
		def events
			unless @events
				self.events = []
			end

			@events
		end
		def events=(x)
			x = Set.new(x)

			return @events if @old_events == x

			begin
				_set_events(*x)

				@events = CallerProxy.new(x){|o| self.events = o}
				@old_events = x.clone
			rescue TorError
				# Make sure the modification is rejected.
				@events.__wrapped.replace(@old_events)

				raise $!
			end

			@events
		end

		# Register ourselves for +events+. Unlike the controller's SETEVENTS, this
		# doesn't unregister ourselves for events we're not registered for.
		def set_events(*events)
			self.events += events
		end

		# @return [Symbol] circuit_id
		# @return [Symbol] circuit_status
		# @return [Array<*String>] path
		# @return [Symbol, nil] reason
		# @return [Symbol, nil] remote_reason
		def parse_CIRC_event(first_line, args, kwd_args)
			circuit_id, circuit_status, *other = first_line.split()
			circuit_id = circuit_id.to_sym
			circuit_status = circuit_status.to_sym
			if other[0] !~ /\=/
				path = other[0].split(",")
			else
				path = []
			end

			warn "we don't parse reason or remote_reason at the moment"
			return circuit_id, circuit_status, path, nil, nil
		end

		# @return [String] stream_id
		# @return [Symbol] stream_status
		# @return [String] circ_id
		# @return [Array<String, Fixnum>] target
		# @return [Hash] attrs optional information provided by Tor
		def parse_STREAM_event(first_line, args, kwd_args)
			stream_id, stream_status, circ_id, target, extra = first_line.split($;, 5)
			stream_status = stream_status.to_sym
			target = target.split(':')
			target[1] = target[1].to_i

			attrs = Hash.new
			extra.split.each do |p|
				k, v = p.split("=", 2)
				k = k.downcase.to_sym

				case k
					when :source_addr
						v = v.split(":",2)
						v[1] = v[1].to_i
				end

				attrs[k] = v
			end

			[stream_id, stream_status, circ_id, target, attrs]
		end

		# Handle a stream event. We don't do anything unless we have behavior
		# defined in a subclass.
		def handle_STREAM_event(stream_id, stream_status, circ_id, target, attrs)
			nil
		end

		# We're called by handle_async() when an unknown event type is received.
		def handle_unknown_event(event_type, first_line, args, kwd_args)
			warn "ignoring #{event_type} event: we don't know how to handle it"
		end

		private

		# Register ourselves for +events+, _unregistering_ ourselves for events not
		# present.
		def _set_events(*events)
			@connection.puts("SETEVENTS#{([""]+events).join(" ")}")
			get_response()[0].raise
		end

		# This method is called by +read_and_act_on_reply()+ when an asynchronous
		# reply is received. If, for example, we receive a CIRC event, if we have a
		# method called +handle_CIRC_event()+, then it will be called with
		# like +handle_CIRC_events(first_line, args, kwd_args)+ _unless_ there
		# exists. If no specific
		# method handler for that event type exists, handle_unknown_event() will be5
		# will be called like
		# +handle_unknown_event(event_type, first_line, args, kwd_args)+.
		#
		# @param [lines] This is an Array like the second element get_response()
		#                returns.
		def handle_async(lines)
			event_type, first_line, args, kwd_args = parse_async(lines)

			if respond_to? "handle_#{event_type}_event"
				if respond_to? "parse_#{event_type}_event"
					send(
						"handle_#{event_type}_event",
						*send("parse_#{event_type}_event", first_line, args, kwd_args)
					)
				else
					send("handle_#{event_type}_event", first_line, args, kwd_args)
				end
			else
				handle_unknown_event(event_type, first_line, args, kwd_args)
			end
		end

		# Parse an asynchronous response into the event type, arguments, and keyword
		# arguments.
		# @return [event_type[Symbol], arguments[Array], keyword_arguments[Hash]]
		def parse_async(lines)
			event_type, first_line = lines.shift().split($;, 2)
			event_type = event_type.to_sym

			arguments = []
			keyword_arguments = {}

			lines.each do |l|
				parts = l.split()
				parts.each do |p|
					if p =~ /=/
						kwd, val = p.split("=", 2)
						keyword_arguments[kwd.to_sym] = val
					else
						arguments << p
					end
				end
			end

			[ event_type, first_line, arguments, keyword_arguments ]
		end
	end
end
