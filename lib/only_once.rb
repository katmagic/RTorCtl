#!/usr/bin/ruby

# Do something, but only once (in the lifetime of the program). This is based on
# the output of caller, so there's some possibility for error if you've reloaded
# files, etc.
def only_once
	$only_once_previously_called_from ||= Array.new
	unless $only_once_previously_called_from.include? caller[0]
		$only_once_previously_called_from << caller[0]
		yield
	end
end
