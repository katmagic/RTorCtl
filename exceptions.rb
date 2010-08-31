#!/usr/bin/ruby

class RTorCtl
	class RTorCtlError < Exception
	end

	[
		:ConnectionClosed, :ProtocolError, :ErrorReply, :ParsingError
	].each do |err|
		const_set(err, Class.new(RTorCtlError))
	end
end
