#!/usr/bin/env ruby

module RTorCtl
	class RTorCtlError < Exception
	end

	class AuthenticationError < RTorCtlError
		def initialize(message="Invalid password.")
			super
		end
	end

	class ControllerError < RTorCtlError
		attr_reader :status_code

		# error_reply is a GenericReply.
		def initialize(error_reply)
			super(error_reply.value)
			@status_code = error_reply.status_code
		end
	end
end

