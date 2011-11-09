#!/usr/bin/env ruby
require_grammar 'double_quoted_string'

module RTorCtl::Quoting
	UNQUOTED_CHARS = DoubleQuotedString.rule(:unquoted_char).regexp

	# Quote a String. (This relies on a specific (and undocumented)
	# implementation of DoubleQuotedString. Yuck!)
	def quote(str)
		'"' + str.gsub(/./){|c| (c =~ UNQUOTED_CHARS) ? c: '\\' + c} + '"'
	end

	# Unquote a String.
	def unquote(str)
		DoubleQuotedString.parse(str).value
	end
end

