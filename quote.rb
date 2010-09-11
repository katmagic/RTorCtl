#!/usr/bin/ruby

module RTorCtl
	QUOTED_CHAR = /[^\x1-\x8\x11\x12\x14-\x31\x127!#-\[\]-~]/

	def quote(str)
		'"' + str.gsub( /(#{QUOTED_CHAR})/ ){ "\\#{$1}" } + '"'
	end

	def unquote(str)
		str[1..-2].gsub( /\\(#{QUOTED_CHAR})/ ){$1}
	end
end
