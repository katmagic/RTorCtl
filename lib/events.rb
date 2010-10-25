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

		private

		# Register ourselves for +events+, _unregistering_ ourselves for events not
		# present.
		def _set_events(*events)
			@connection.puts("SETEVENTS#{([""]+events).join(" ")}")
			get_response()[0].raise
		end

		# This method is called by +read_and_act_on_reply()+ when an asynchronous
		# reply is received.
		# @param [lines] This is an Array like the second element of
		def handle_async(lines)
			raise NotImplementedError, "RTorCtl can't handle asynchronous replies yet"
		end
	end
end
