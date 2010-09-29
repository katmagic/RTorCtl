#!/usr/bin/ruby

module RTorCtl
	QUOTED_CHAR = /[^\x1-\x8\x11\x12\x14-\x31\x127!#-\[\]-~]/

	# These have to be constants because methods in a module are apparently not
	# inherited by classes in that module. How inelegant. Grr.

	Quote = Proc.new do |str|
		'"' + str.gsub( /(#{QUOTED_CHAR})/ ){ "\\#{$1}" } + '"'
	end

	Unquote = Proc.new do |str|
		str[1..-2].gsub( /\\(#{QUOTED_CHAR})/ ){$1}
	end
end
