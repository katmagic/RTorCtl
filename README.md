RTorCtl: A Rubyonic Interface to Tor's Control Port
====================================================

**Homepage**: [GitHub](https://github.com/katmagic/RTorCtl)  
**Git**: [GitHub](git://github.com/katmagic/RTorCtl.git)  
**License**: [UNLICENSE](http://unlicense.org)  
**Author**: [katmagic](mailto:the.magical.kat@gmail.com) ([E51DFE2C][key])  
[key]: https://keyserver.pgp.com/vkd/DownloadKey.event?keyid=0xD1EACB65E51DFE2C>

Installation
------------

We're currently only suitable for development, really, so we're not available
from RubyGems, so you'll have to download us and require `lib/rtorctl`
yourself. You'll also need to download and install the _[highline][HighLine]_
and _[only\_once][only_once]_ gems.
[HighLine]: http://highline.rubyforge.org/
[only_once]: https://rubygems.org/gems/only_once/

Prior to Instantiation
----------------------

By default, RTorCtl will use environment variables to determine your
controller's password. If you're using a password, just set `$TORCTL_PASSWD` to
whatever your password is; if your're using a cookie file, set
`$TORCTL_PASSWD_FILE` to the location of this file. Be careful to make sure that
the cookie file is readable by the current user!

Also, the command line options `-passwd=<passwd>` and
`-passwd_file=<passwd_file>` have the same effects as their corresponding
environment variables.

If _that_ fails, it'll try asking you for the password, if STDIN and STDOUT are
both on a tty.

Instantiation
-------------

	require 'rtorctl'

	tor = RTorCtl::RTorCtl.new

Searching for Relays
--------------------

Populating the list of relays is a somewhat expensive process; because of this,
`tor.relays` is cached, so only the first access should block significantly.

	# Find all the stable relays that exit to port 6697.
	tor.relays.find_all{ |relay|
		[:Running, :Stable].all?{|x| relay.flags.include? x} and
		relay.condensed_exit_policy.accepts?("0.0.0.0", 6697)
	}

	# How many relays are there?
	tor.relays.count
	# How many of them are exits?
	tor.relays.count{ |r| r.flags.include? :Exit }

	# Find all the relays in 12.0.0.0/8.
	tor.relays.find_all{ |r| r.ip/8 === "12.0.0.0" }
	# How many /8 netblocks does Tor have relays in?
	tor.relays.map{ |r| (r.ip/8)[0] }.uniq.count

CAUTION: At the moment, searching for attributes not in RelayInitializer is
*very* time consuming.

Sending Signals
---------------

	# Make Tor put new streams on clean circuits.
	tor.signal(:NEWNYM)

Getting Other Information
-------------------------

RTorCtl still has a lot of missing functionality. To get an unpolished interface
to a lot of the data that Tor provides, you can use `getinfo()`. `getinfo()`
returns either a String consisting of the one line response or an Array
consisting of Strings (one for each line of the response).

	tor.getinfo("config-file") # "/usr/local/etc/tor/torrc"

	tor.getinfo("address-mappings/all")
	# ['www.gravatar.com 72.233.69.5 "2010-04-20 04:20:00"',
	#  'github.com 207.97.227.239 "2010-04-20 04:20:00"']

`getconf()` can also be used to get information. `getconf()` returns results in
a semi-structured form, see the `*_CONFOPT` constants in RTorCtl defined in
`getinfo.rb` for which type values will be converted to specifically.

	tor.getconf(:SocksPort) # 9051
	tor.getconf(:FirewallPorts) # [80, 443]
	tor.getconf(:SafeLogging) # true
	tor.getconf(:CookieAuthFile) # "/tmp/control_cookie"

Assigning Configuration Values
------------------------------

	tor.setconf(:SocksPort, 9050)
	tor.setconf(:SocksPort => 9050, :ORPort => 443)

Useful Things to do with RTorCtl
--------------------------------

### Avoiding the NSA: A Multi-Step Example ###

	# Find nodes operated by the NSA.
	nsa = tor.relays.find_all{|r| r.nickname.chars.to_a & %w{n s a} == %w{n s a} }
	# Get their nicknames.
	nsa.map!{|r| r.nickname}
	# Avoid them.
	tor.setconf(:ExcludeNodes => nsa, :StrictNodes => true)
