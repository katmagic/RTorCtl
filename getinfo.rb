#!/usr/bin/ruby
require 'parse_response'

module RTorCtl
	class RTorCtl
		def getinfo(*keywords)
			# Get some data from Tor in a somewhat generic fashion. Return a hash with
			# keywords mapped to their returned values.

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
		MULTI_INT_CONFOPT = [:FirewallPorts, :LongLivedPorts ]
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
		MULTI_STR_CONFOPT = [
			:TrackHostExits, :AutomapHostsSuffixes, :ServerDNSTestAddresses,
			:RecommendedVersions, :RecommendedClientVersions,
			:RecommendedServerVersions, :AuthDirBadDir, :AuthDirBadExit,
			:AuthDirInvalid, :AuthDirReject, :HiddenServiceVersion
		]
		SPECIAL_CONFOPT = [
			:DirServer, :AlternateDirAuthority, :AlternateHSAuthority,
			:AlternateBridgeAuthority, :Log, :AllowInvalidNodes, :Bridge,
			:ExcludeNodes, :ExcludeExitNodes, :EntryNodes, :ExitNodes,
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

		def convert_option(opt, val)
			case opt.to_sym
				when INT_CONFOPT then val.to_i
				when MULTI_INT_CONFOPT then val.split(",").map{|x|x.to_i}
				when BOOL_CONFOPT then val == "1"
				when STR_CONFOPT then val
				when MULTI_STR_CONFOPT then val.split(",")
				when SPECIAL_CONFOPT
					if private_methods.include? "convert_opt_#{opt}"
						send("opt_convert_#{opt}", val)
					else
						val
					end
				else val
			end
		end
		private :convert_option

		def getconf(*keywords)
			# tor.getconf(:SocksPort) # "9050"
			# tor.getconf(:SocksPort, :ControlPort)
			# # {"SocksPort"=>"9050", "ControlPort"=>"9051"}

			@connection.puts("GETCONF #{keywords.join(" ")}")
			code, response = get_response()

			code.raise()

			if keywords.length == 1
				return convert_option(keywords[0], response[0].split("=", 2)[1])

			else
				results = Hash.new

				response.each do |x|
					key, value = x.split("=", 2)
					results[key] = convert_option(key, value)
				end

				return results
			end
		end
	end
end
