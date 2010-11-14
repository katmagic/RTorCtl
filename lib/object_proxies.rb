#!/usr/bin/ruby
# Proxies!

# BasicObject exists by default in Ruby 1.9, so it might already exist.
unless defined? BasicObject
	# BasicObject only has the minimal __send__ and __id__ methods. It's a useful
	# base class for proxies.
	class BasicObject
		undef_method *(instance_methods - ['__send__', '__id__'])
	end
end

# Call a method after a method of a proxied object is called.
class CallerProxy < BasicObject
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


# Give a block to be evaluated lazily. The result is cached.
class DelayedResult < BasicObject
	def initialize(&block)
		@block = block
	end

	def method_missing(m, *a, &b)
		@obj = @block.call() unless defined? @obj

		@obj.__send__(m, *a, &b)
	end
end
