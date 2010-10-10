#!/usr/bin/ruby
require 'parse_response'

module RTorCtl
	class RTorCtl
		# Get some data from Tor in a somewhat generic fashion.
		# @overload getinfo(keyword)
		#  @param [#to_s] keyword a keyword to pass to GETINFO
		#  @return [String] Tor's response
		# @overload getinfo(*keywords)
		#  @param [Array] keywords an array of keywords to pass to GETINFO
		#  @return [Array] the array of responses
		# @see section 3.9 of control-spec.txt
		def getinfo(*keywords)

			@connection.puts("GETINFO #{keywords.join(" ")}")
			code, response = get_response()

			code.raise()

			info = Hash.new
			response[0...-1].each do |r|
				if r.is_a? Array
					info[r[0].chomp("=").to_sym] = r[1]
				else
					name, val = r.split("=", 2)
					info[name.to_sym] = val
				end
			end

			keywords.length == 1 ? info.first[1] : info
		end

		# These options will have their values returned as +Fixnum+.
		INT_CONFOPT = [
			:SocksPort, :BandwidthRate, :BandwidthBurst, :MaxAdvertisedBandwidth,
			:RelayBandwidthRate, :RelayBandwidthBurst, :PerConnBWRate,
			:PerConnBWBurst, :ConLimit, :ConstrainedSockSize, :ControlPort,
			:KeepalivePeriod, :CircuitPriorityHalflife, :CircuitBuildTimeout,
			:CircuitIdleTimeout, :CircuitStreamTimeout, :NewCircuitPeriod,
			:MaxCircuitDirtiness, :SocksPort, :SocksTimeout, :TrackHostExitsExpire,
			:NumEntryGaurds, :TransPort, :DNSPort, :MaxOnionsPending, :NumCPUs,
			:ORPort, :ShutdownWaitLength, :AccountingMax, :MinUptimeHidServDirectory,
			:DirPort, :AuthDirMaxServersPerAddr, :AuthDirMaxServersPerAuthAddr,
			:V3AuthVotingInterval, :V3AuthVoteDelay, :V3AuthNIntervalsValid,
			:RendPostPeriod, :TestingV3AuthInitialVotingInterval,
			:TestingV3AuthInitialVoteDelay, :TestingV3AuthInitialDistDelay,
			:TestingAuthDirTimeToLearnReachability,
			:TestingEstimatedDescriptorPropagationTime
		]
		# These options will be +Array+s of +Fixnum+.
		MULTI_INT_CONFOPT = [:FirewallPorts, :LongLivedPorts]
		# These options will be +true+ or +false+.
		BOOL_CONFOPT = [
			:SafeLogging, :ConstrainedSockets, :CookieAuthentication,
			:CookieAuthFileGroupReadable, :DisableAllSwap, :FetchDirInfoEarly,
			:FetchDirInfoExtraEarly, :FetchHidServDescriptors,
			:FetchServerDescriptors, :FetchUselessDescriptors, :ProtocolWarnings,
			:RunAsDaemon, :HardwareAccel, :AvoidDiskWrites, :TunnelDirConns,
			:PreferTunneledDirConns, :ExcludeSingleHopRelays, :ClientOnly,
			:StrictNodes, :FascistFirewall, :EnforceDistinctSubnets,
			:UpdateBridgesFromAuthority, :UseBridges, :UseEntryGaurds, :SafeSocks,
			:TestSocks, :AllowNonRFC953Hostnames, :AllowDotExit, :FastFirstHopPK,
			:AutomapHostsOnResolve, :ClientDNSRejectInternalAddresses,
			:DownloadExtraInfo, :AllowSingleHopExits, :AssumeReachable, :BridgeRelay,
			:ExitPolicyRejectPrivate, :ServerDNSAllowBrokenConfig,
			:ServerDNSSearchDomains, :ServerDNSDetectHijacking,
			:ServerDNSAllowNonRFC953Hostnames, :BridgeRecordUsageByCountry,
			:ServerDNSRandomizeCase, :CellStatistics, :DirReqStatistics,
			:ExitPortStatistics, :ExtraInfoStatistics, :AuthoritativeDirectory,
			:V1AuthoritativeDirectory, :V2AuthoritativeDirectory,
			:V3AuthoritativeDirectory, :VersioningAuthoritativeDirectory,
			:NamingAuthoritativeDirectory, :HSAuthoritativeDir, :HidServDirectoryV2,
			:BridgeAuthoritativeDir, :DirAllowPrivateAddresses, :AuthDirListBadDirs,
			:AuthDirListBadExits, :AuthDirRejectUnlisted, :PublishHidServDescriptors,
			:TestingTorNetwork
		]
		# These options will be +String+s.
		STR_CONFOPT = [
			:ControlListenAddress, :ControlSocket, :HashedControlPassword,
			:CookieAuthFile, :DataDirectory, :HTTPProxy, :HTTPProxyAuthenticator,
			:HTTPSProxy, :HTTPSProxyAuthenticator, :Socks4Proxy, :Socks5Proxy,
			:Socks5ProxyUsername, :Socks5ProxyPassword, :OutboundBindAddress,
			:PidFile, :User, :AccelName, :AccelDir, :SocksListenAddress,
			:VirtualAddrNetwork, :TransListenAddress, :FallbackNetworkstatusFile,
			:Address, :ContactInfo, :Nickname, :ORListenAddress,
			:ServerDNSResolvConfFile, :GeoIPFile, :DirPortFrontPage, :DirListenAddress
		]
		# These options will be +Array+s of +String+s.
		MULTI_STR_CONFOPT = [
			:TrackHostExits, :AutomapHostsSuffixes, :ServerDNSTestAddresses,
			:RecommendedVersions, :RecommendedClientVersions,
			:RecommendedServerVersions, :AuthDirBadDir, :AuthDirBadExit,
			:AuthDirInvalid, :AuthDirReject, :HiddenServiceVersion,
			:ExcludeNodes, :ExcludeExitNodes, :EntryNodes, :ExitNodes,
		]
		# These options will be converted on a case-by-case basis.
		SPECIAL_CONFOPT = [
			:DirServer, :AlternateDirAuthority, :AlternateHSAuthority,
			:AlternateBridgeAuthority, :Log, :AllowInvalidNodes, :Bridge,
			:HidServAuth, :ReachableAddresses, :ReachableDirAddresses,
			:ReachableDirAddresses, :ReachableORAddresses, :MapAddress, :NodeFamily,
			:SocksPolicy, :DNSListenAddress, :WarnPlaintextPorts,
			:RejectPlaintextPorts, :ExitPolicy, :MyFamily, :PublishServerDescriptors,
			:AccountingStart, :DirPolicy, :ConsensusParams, :HiddenServiceDir,
			:HiddenServicePort, :HiddenServiceAuthorizeClient
		]
		[INT_CONFOPT, MULTI_INT_CONFOPT, BOOL_CONFOPT, STR_CONFOPT,
		 MULTI_STR_CONFOPT, SPECIAL_CONFOPT].each do |c|
			# Make the case statement in convert_option much neater.
			class << c
				def ===(x)
					include? x
				end
			end
		end

		# Convert +val+ to a format that makes the most sense for it to be
		# represented as in a Ruby object on the basis of +opt+.
		# @param [Symbol] opt the [Tor] option name
		# @param [String] val the String to be converted
		# @return [Object] the converted value
		def convert_option_getter(opt, val)
			case opt.to_sym
				when INT_CONFOPT then val.to_i
				when MULTI_INT_CONFOPT then val.split(",").map{|x|x.to_i}
				when BOOL_CONFOPT then val == "1"
				when STR_CONFOPT then val
				when MULTI_STR_CONFOPT then val.split(",")
				when SPECIAL_CONFOPT
					if private_methods.include? "convert_opt_#{opt}_getter"
						send("opt_convert_#{opt}_getter", val)
					else
						val
					end
				else val
			end
		end

		# Convert +val+ to a String that would make sense to Tor.
		# @param [Symbol] opt the [Tor] option name
		# @param val the value to be converted
		# @return [String] the converted value
		def convert_option_setter(opt, val)
			case opt.to_sym
				when INT_CONFOPT then val.to_s
				when MULTI_INT_CONFOPT then val.join(",")
				when BOOL_CONFOPT then val ? "1" : "0"
				when STR_CONFOPT then val
				when MULTI_STR_CONFOPT then val.join(",")
				when SPECIAL_CONFOPT
					if private_methods.include? "opt_convert_#{opt}_setter"
						send("opt_convert_#{opt}_getter", val)
					else
						val
					end
				else val
			end
		end

		private :convert_option_getter, :convert_option_setter

=begin
Get a configuration value from Tor.
@see section 3.3 of control-spec.txt

@overload getconf(keyword)
 @param [String] keyword
 @return [String] Tor's respons
 @example
  tor.getconf(:SocksPort) # "9050"

@overload getconf(*keywords)
 @param [Array] keywords an array of keywords
 @return [Hash] a Hash of keyword-response pairs
 @example
  tor.getconf(:SocksPort, :ControlPort) # {:SocksPort=>9050, :ControlPort=>9051}
=end
		def getconf(*keywords)
			@connection.puts("GETCONF #{keywords.join(" ")}")
			code, response = get_response()

			code.raise()

			if keywords.length == 1
				return convert_option_getter(keywords[0], response[0].split("=", 2)[1])

			else
				results = Hash.new

				response.each do |x|
					key, value = x.split("=", 2); key = key.to_sym
					results[key] = convert_option_setter(key, value)
				end

				return results
			end
		end

		# Set Tor's configuration options.
		# @overload setconf(option, value)
		#  @param [String, Symbol] option
		#  @param [Object] value a value to be converted to Tor-speak
		#  @see section 3.1 of control-spec.txt
		# @overload setconf(options)
		#  @param [Hash] options a hash of key/value pairs to set
		def setconf(opt, val=nil)
			unless opt.is_a? Hash
				opt = {opt => val}
			end

			opt.each do |key, val|
				opt[key] = convert_option_setter(key, val)
			end

			@connection.puts("SETCONF #{opt.map{|a,b|"#{a}=#{b}"}.join(" ")}")
			code, response = get_response()
			code.raise()
		end
	end
end
