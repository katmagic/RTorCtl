#!/usr/bin/ruby

module RTorCtl
	# This class represents a response code recieved from Tor.
	# @see section 4 of Tor's control-spec.txt
	class Code
		DESCRIPTIONS = {
			250 => "OK",
			251 => "Operation was unnecessary",
			451 => "Resource exhausted",
			500 => "Syntax error: protocol",
			510 => "Unrecognized command",
			511 => "Unimplemented command",
			512 => "Syntax error in command argument",
			513 => "Unrecognized command argument",
			514 => "Authentication required",
			515 => "Bad authentication",
			550 => "Unspecified Tor error",
			551 => "Internal error",
			552 => "Unrecognized entity",
			553 => "Invalid configuration value",
			554 => "Invalid descriptor",
			555 => "Unmanaged entity",
			650 => "Asynchronous event notification"
		}

		# the [Fixnum] response code
		attr_reader :code

		# @param [Fixnum] code a response code from Tor
		def initialize(code)
			@code = code.to_i
		end

		# @return [Symbol] one of +:positive_completion+,
		#  +:temporary_negative_completion+, +:permanent_negative_completion+, or
		#  +:asynchronous+
		def reply_type
			case @code
				when 200...300 then :positive_completion
				when 300...400 then :temporary_negative_completion
				when 500...600 then :permanent_negative_completion
				when 600...700 then :asynchronous
				else :UNKNOWN
			end
		end

		[	:positive_completion, :temporary_negative_completion,
			:permanent_negative_completion, :asynchronous ].each do |reply_type|
			define_method( "#{reply_type}?" ) { reply_type() == reply_type }
		end

		# @return [Symbol] one of +:syntax+, +:protocol+, or +:tor+
		def secondary_reply_type
			case @code % 100
				when 00...10 then :syntax
				when 10...20 then :protocol
				when 50...60 then :tor
				else :UNKNOWN
			end
		end

		# Is this a successful reply?
		def success?()
			[:positive_completion, :asynchronous].include?( reply_type )
		end

		# a short description of the reply
		def desc
			DESCRIPTIONS[@code]
		end
		alias :to_s :desc

		def to_i
			@code
		end

		def inspect
			"#<#{self.class.name} #{@code}>"
		end

		# Return ourselves into a TorError, or nil if we're a success.
		def exception
			return nil if success?

			TorError.new(self)
		end

		# Raise ourselves as an exception.
		# @see Code#exception
		def raise
			return nil if success?

			e = exception
			e.set_backtrace( caller )

			Kernel.raise e
		end

		def ==(x)
			case x
				when Numeric then x == @code
				when self.class then x.code == @code
				else false
			end
		end
	end

	# This class is instanstiated by Code#exception
	# @see Code#exception
	class TorError < Exception
		# one of +:syntax+, +:protocol+, or +:tor+
		attr_reader :error_type
		# one of +:PERMANENT+, +:TEMPORARY+, or +:UNKNOWN+
		attr_reader :error_expiry

		# @param [Code] error the Code to derive the response from
		def initialize(error)
			super(error.desc)

			@error_type = error.secondary_reply_type
			case error.reply_type
				when :permanent_negative_completion then :PERMANENT
				when :temporary_negative_completion then :TEMPORARY
				else :UNKNOWN
			end
		end
	end
end
