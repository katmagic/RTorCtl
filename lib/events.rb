#!/usr/bin/ruby

module RTorCtl
	class RTorCtl
		private

		# This method is called by +read_and_act_on_reply()+ when an asynchronous
		# reply is received.
		# @param [lines] This is an Array like the second element of
		def handle_async(lines)
			raise NotImplementedError, "RTorCtl can't handle asynchronous replies yet"
		end
	end
end
