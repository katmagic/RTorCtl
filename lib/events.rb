#!/usr/bin/ruby
require 'set'

module RTorCtl
	# Call a method after a method of a proxied object is called.
	class CallerProxy
		undef_method *(instance_methods - ['__send__', '__id__'])

		# +hook+ will be called with +proxied_object+ as the sole argument every
		# time a method is called.
		def initialize(proxied_object, &hook)
			@hook = hook
			@obj = proxied_object
		end

		def method_missing(m, *a, &p)
			ret = @obj.__send__(m, *a, &p)
			@hook.call(@obj)
			return ret
		end

		def __wrapped
			@obj
		end
	end

	class RTorCtl
		# Modifying or assigning events _will_ cause _set_events to be called with
		# events.
		def events
			@events or self.events = []
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
		# like +handle_CIRC_events(first_line, args, kwd_args)+. If no specific
		# method handler for that event type exists, handle_unknown_event() will be5
		# will be called like
		# +handle_unknown_event(event_type, first_line, args, kwd_args)+.
		#
		# @param [lines] This is an Array like the second element get_response()
		#                returns.
		def handle_async(lines)
			event_type, first_line, args, kwd_args = parse_async(lines)

			if respond_to? "handle_#{event_type}_event"
				send("handle_#{event_type}_event", first_line, args, kwd_args)
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
