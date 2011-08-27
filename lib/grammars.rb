#!/usr/bin/env ruby
# This file just loads all our Citrus grammars.
require 'citrus'

module RTorCtl
	# Load all of our grammars.
	def load_grammars()
		# This is a really long way of saying ../grammars/.
		dot_dot = File.dirname(File.absolute_path(File.dirname(__FILE__)))
		grammar_dir = File.join(dot_dot, 'grammars')

		Dir.entries(grammar_dir).grep(/\.citrus$/) do |grammar|
			Citrus.load( File.join(grammar_dir, grammar) )
		end
	end

	Object.new.extend(self).load_grammars()
end

