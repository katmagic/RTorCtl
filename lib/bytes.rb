#!/usr/bin/ruby

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

	%w{ b kb mb gb tb }.each_with_index do |abbrev, index|
		define_method(abbrev){ @i / 1024.0**index }
	end

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
