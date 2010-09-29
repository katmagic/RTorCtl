#!/usr/bin/ruby

module RTorCtl
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

		attr_reader :code

		def initialize(code)
			@code = code.to_i
		end

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

		def secondary_reply_type
			case @code % 100
				when 00...10 then :syntax
				when 10...20 then :protocol
				when 50...60 then :tor
				else :UNKNOWN
			end
		end

		def success?()
			[:positive_completion, :asynchronous].include?( reply_type )
		end

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

		def exception
			return nil if success?

			TorError.new(self)
		end

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

	class TorError < Exception
		attr_reader :error_type, :error_expiry

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
