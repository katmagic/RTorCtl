module RTorCtl
	class GenericReply
		def has_data?
			case @data.length
				when 0 then false
				when 1 then true
				else :many
			end
		end

		# If as_array is true, our return value will be an Array of Strings. If
		# as_array if false, data will be a String, and an exception will be
		# raised if multiple data values, or no data values at all, were given.
		# Otherwise, we will return an Array if multiple values were given, a
		# String if only one value was given, or nil if no values were given.
		def data(as_array=nil)
			if as_array == true
				@data
			elsif as_array == false
				case @data.length
					when 0
						raise "no data was provided"
					when 1
						@data.first
					else
						raise "multiple data values were provided"
				end
			elsif as_array == nil
				case @data.length
					when 0 then nil
					when 1 then @data.first
					else @data
				end
			end
		end

		attr_reader :status_code

		# lines is an Array of Strings containing the replies given by the
		# controller (excluding the data). They do not contain CRLFs.
		attr_reader :lines

		# We return our first line, but raise an exception if we have more than one.
		def value
			if @lines.length == 1
				@lines.first
			else
				raise "value was called when there were multiple lines"
			end
		end

		# We should only be initialized from the ControllerReply grammar. lines is
		# an Array of *_reply_lines. data_reply_lines should have a data attribute
		# containing their data, and all reply lines should have a status_code
		# attribute containing their (integer) status code. *_reply_lines should not
		# contain their status code, nor should they contain a CRLF; however
		# data_reply_line.data *SHOULD* contain a trailing CRLF..
		def initialize(lines)
			@data = Array.new
			@lines = Array.new

			lines.each do |l|
				if l.has_data?
					@data << (l.data + "\r\n")
				end

				if @status_code and @status_code != l.status_code.to_i
					raise "incongruent status codes"
				elsif not @status_code
					@status_code = l.status_code.to_i
				end

				@lines << l.value
			end

			@lines.freeze
			@data.freeze
		end
	end

	class ReplyLine < Struct.new(:status_code, :value, :data)
		def has_data?
			data != nil
		end
	end

	module ReplyLineInclude
		def value
			ReplyLine.new(status_code.to_i, reply_line.value,
			              data && data.value).freeze
		end
	end
end

require_grammar 'misc_data'
require_grammar 'controller_reply'
