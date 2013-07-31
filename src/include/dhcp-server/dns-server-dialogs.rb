# encoding: utf-8

# File:	include/dhcp-server/dns-server-dialogs.ycp
# Package:	Configuration of dhcp-server
# Summary:	Synchronization with DNS Server (shared dialogs)
# Authors:	Lukas Ocilka <lukas.ocilka@suse.cz>
#
# $Id$
module Yast
  module DhcpServerDnsServerDialogsInclude
    def initialize_dhcp_server_dns_server_dialogs(include_target)
      Yast.import "UI"

      textdomain "dhcp-server"

      Yast.import "IP"
      Yast.import "Label"
      Yast.import "Report"
      Yast.import "Punycode"
      Yast.import "Hostname"
      Yast.import "DnsServerAPI"
    end

    def IsDNSZoneMaintained(zone_name)
      if zone_name == nil
        Builtins.y2error("Undefined zone name")
        return nil
      end

      all_zones = DnsServerAPI.GetZones

      # found or not?
      Ops.get(all_zones, zone_name) == nil
    end

    def IsDNSZoneMaster(zone_name)
      if zone_name == nil
        Builtins.y2error("Undefined zone name")
        return nil
      end

      all_zones = DnsServerAPI.GetZones

      # if zone not found
      ret = nil

      # is master or not?
      if Ops.get(all_zones, zone_name) != nil
        ret = Ops.get(all_zones, [zone_name, "type"]) == "master"
      end

      ret
    end

    def CreateUI_DNSRangeDialog(range_min, range_max, old_range)
      old_range = deep_copy(old_range)
      # old_range: $[
      #     "base"  : "dhcp-%",
      #     "start" : 0,
      #     "from"  : "192.168.10.1",
      #     "to"    : "192.168.10.100"
      # ]

      # TRANSLATORS: dialog caption
      dialog_caption = _("Add New DNS Record Range")
      if old_range != {} && old_range != nil
        # TRANSLATORS: dialog caption
        dialog_caption = _("Edit DNS Record Range")
      end

      UI.OpenDialog(
        VBox(
          MarginBox(
            1,
            1,
            Frame(
              dialog_caption,
              VBox(
                HBox(
                  # TRANSLATORS: text entry
                  TextEntry(Id("current_range_min"), _("Min&imum IP Address")),
                  # TRANSLATORS: text entry
                  TextEntry(Id("current_range_max"), _("Ma&ximum IP Address"))
                ),
                HBox(
                  # TRANSLATORS: text entry
                  TextEntry(Id("hostname_base"), _("&Hostname Base")),
                  # TRANSLATORS: text entry
                  TextEntry(Id("hostname_start"), _("&Start"))
                ),
                HBox(
                  # TRANSLATORS: text entry
                  TextEntry(Id("first_ip"), _("&First IP Address")),
                  # TRANSLATORS: text entry
                  TextEntry(Id("last_ip"), _("&Last IP Address"))
                )
              )
            )
          ),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(Id("current_range_min"), :Value, range_min)
      UI.ChangeWidget(Id("current_range_max"), :Value, range_max)

      # FIXME: default
      UI.ChangeWidget(
        Id("hostname_base"),
        :Value,
        Ops.get_string(old_range, "base", "dhcp-%i")
      )
      UI.ChangeWidget(
        Id("hostname_start"),
        :Value,
        Builtins.tostring(Ops.get_integer(old_range, "start", 1))
      )

      UI.ChangeWidget(Id("current_range_min"), :Enabled, false)
      UI.ChangeWidget(Id("current_range_max"), :Enabled, false)

      UI.ChangeWidget(Id("first_ip"), :ValidChars, IP.ValidChars4)
      UI.ChangeWidget(Id("last_ip"), :ValidChars, IP.ValidChars4)
      UI.ChangeWidget(Id("hostname_start"), :ValidChars, "0123456789")

      # Predefining possible values
      UI.ChangeWidget(
        Id("first_ip"),
        :Value,
        Ops.get_string(old_range, "from", range_min)
      )
      UI.ChangeWidget(
        Id("last_ip"),
        :Value,
        Ops.get_string(old_range, "to", range_max)
      )

      nil
    end

    def CheckDNSRange(first_ip, last_ip, current_d_settings)
      # range in binary form
      first_ip_bin = IP.IPv4ToBits(first_ip)
      last_ip_bin = IP.IPv4ToBits(last_ip)

      # they have to be defined
      if first_ip_bin == nil || last_ip_bin == nil
        Report.Error(
          Builtins.sformat(
            # TRANSLATORS: popup error, %1 is the first IP of the range, %2 is the last one
            _("Internal error.\nCannot create IP range from %1 and %2."),
            first_ip,
            last_ip
          )
        )
        return false
      end

      # network mask in binary form
      bits = Builtins.tointeger(
        Ops.get(current_d_settings.value, "netmask_bits")
      )
      network_bits = Ops.get(current_d_settings.value, "network_binary")
      # first x bits from network in binary form
      network_bits = Builtins.substring(network_bits, 0, bits)
      Builtins.y2milestone("Network Mask: %1", network_bits)

      # doest the first IP match the current network?
      first_ip_mask = Builtins.substring(first_ip_bin, 0, bits)
      # network bits must be the same in both IP and Network
      if first_ip_mask != network_bits
        Report.Error(
          # TRANSLATORS: popup error, %1 is an IP address
          # %2 is a network, %3 is a netmask
          Builtins.sformat(
            _("IP address %1 does not match\nthe current network %2/%3.\n"),
            first_ip,
            Ops.get(current_d_settings.value, "network", ""),
            Ops.get(current_d_settings.value, "netmask", "")
          )
        )
        UI.SetFocus(Id("first_ip"))
        return false
      end

      # does the second IP match the current network?
      last_ip_mask = Builtins.substring(last_ip_bin, 0, bits)
      # network bits must be the same in both IP and Network
      if last_ip_mask != network_bits
        Report.Error(
          Builtins.sformat(
            _("IP address %1 does not match\nthe current network %2/%3.\n"),
            last_ip,
            Ops.get(current_d_settings.value, "network", ""),
            Ops.get(current_d_settings.value, "netmask", "")
          )
        )
        UI.SetFocus(Id("last_ip"))
        return false
      end

      # the Address part of IPs
      first_ip_bin = Builtins.substring(first_ip_bin, bits)
      last_ip_bin = Builtins.substring(last_ip_bin, bits)
      Builtins.y2milestone("First IP: %1", first_ip_bin)
      Builtins.y2milestone("Last IP:  %1", last_ip_bin)

      # the Address part of the DHCP range
      fist_ip_dhcp = IP.IPv4ToBits(
        Ops.get(current_d_settings.value, "from_ip", "")
      )
      last_ip_dhcp = IP.IPv4ToBits(
        Ops.get(current_d_settings.value, "to_ip", "")
      )
      fist_ip_dhcp = Builtins.substring(fist_ip_dhcp, bits)
      last_ip_dhcp = Builtins.substring(last_ip_dhcp, bits)

      # isn't the first IP bigger than the last one?
      if Ops.greater_than(
          Builtins.tointeger(first_ip_bin),
          Builtins.tointeger(last_ip_bin)
        )
        # TRANSLATORS: popup error
        Report.Error(
          _("The last IP address must be higher than the first one.")
        )
        return false
      end

      # isn't the first IP out of the current DHCP range?
      if Ops.less_than(
          Builtins.tointeger(first_ip_bin),
          Builtins.tointeger(fist_ip_dhcp)
        ) ||
          Ops.greater_than(
            Builtins.tointeger(fist_ip_dhcp),
            Builtins.tointeger(last_ip_dhcp)
          )
        Report.Error(
          Builtins.sformat(
            # TRANSLATORS: popup error, %1 an IP address
            # %2 is the first IP address of the range, %3 is the last one
            _(
              "The IP address %1 is\n" +
                "outside the current\n" +
                "dynamic DHCP range %2-%3.\n"
            ),
            first_ip,
            Ops.get(current_d_settings.value, "from_ip", ""),
            Ops.get(current_d_settings.value, "to_ip", "")
          )
        )
        return false
      end

      # isn't the last IP out of the current DHCP range?
      if Ops.less_than(
          Builtins.tointeger(last_ip_bin),
          Builtins.tointeger(fist_ip_dhcp)
        ) ||
          Ops.greater_than(
            Builtins.tointeger(last_ip_dhcp),
            Builtins.tointeger(last_ip_dhcp)
          )
        Report.Error(
          Builtins.sformat(
            # TRANSLATORS: popup error, %1 an IP address
            # %2 is the first IP address of the range, %3 is the last one
            _(
              "The IP address %1 is\n" +
                "outside the current\n" +
                "dynamic DHCP range %2-%3.\n"
            ),
            last_ip,
            Ops.get(current_d_settings.value, "from_ip", ""),
            Ops.get(current_d_settings.value, "to_ip", "")
          )
        )
        return false
      end

      true
    end

    def IPisInRangeOfIPs(ipv4, first_ip, last_ip)
      # Checking delta between first_ip and last_ip
      ipv4_list = Builtins.maplist(Builtins.splitstring(ipv4, ".")) do |ip_part|
        Builtins.tointeger(ip_part)
      end
      first_ip_list = Builtins.maplist(Builtins.splitstring(first_ip, ".")) do |ip_part|
        Builtins.tointeger(ip_part)
      end
      last_ip_list = Builtins.maplist(Builtins.splitstring(last_ip, ".")) do |ip_part|
        Builtins.tointeger(ip_part)
      end

      # Computing deltas
      # 195(.168.0.1) - 192(.11.0.58) => 3
      address_1_1 = Ops.subtract(
        Ops.get(ipv4_list, 0, 0),
        Ops.get(first_ip_list, 0, 0)
      )
      address_1_2 = Ops.subtract(
        Ops.get(ipv4_list, 1, 0),
        Ops.get(first_ip_list, 1, 0)
      )
      address_1_3 = Ops.subtract(
        Ops.get(ipv4_list, 2, 0),
        Ops.get(first_ip_list, 2, 0)
      )
      address_1_4 = Ops.subtract(
        Ops.get(ipv4_list, 3, 0),
        Ops.get(first_ip_list, 3, 0)
      )

      address_2_1 = Ops.subtract(
        Ops.get(last_ip_list, 0, 0),
        Ops.get(ipv4_list, 0, 0)
      )
      address_2_2 = Ops.subtract(
        Ops.get(last_ip_list, 1, 0),
        Ops.get(ipv4_list, 1, 0)
      )
      address_2_3 = Ops.subtract(
        Ops.get(last_ip_list, 2, 0),
        Ops.get(ipv4_list, 2, 0)
      )
      address_2_4 = Ops.subtract(
        Ops.get(last_ip_list, 3, 0),
        Ops.get(ipv4_list, 3, 0)
      )

      range_status = nil

      # Firstly, checking the IPv4 and the first address in the range
      # IPv4 must be bigger or equal to it
      if ipv4 == first_ip
        range_status = true 

        # first chunk is either smaller or bigger than zero
      elsif Ops.less_than(address_1_1, 0) || Ops.greater_than(address_1_1, 0)
        # bigger means that the IP range is correct
        range_status = Ops.greater_than(address_1_1, 0) 

        # if they are equal, check the very next chunk...
      elsif Ops.less_than(address_1_2, 0) || Ops.greater_than(address_1_2, 0)
        range_status = Ops.greater_than(address_1_2, 0)
      elsif Ops.less_than(address_1_3, 0) || Ops.greater_than(address_1_3, 0)
        range_status = Ops.greater_than(address_1_3, 0)
      elsif Ops.less_than(address_1_4, 0) || Ops.greater_than(address_1_4, 0)
        range_status = Ops.greater_than(address_1_4, 0) 

        # what else?
      else
        Builtins.y2error(
          "Unknown match IP: %1 First: %2",
          ipv4_list,
          first_ip_list
        )
        range_status = false
      end

      # First checking didn't match
      return false if !range_status

      # Secondly, checking the IPv4 and the last address in the range
      # IPv4 must be smaller or equal to it
      if ipv4 == last_ip
        range_status = true 

        # first chunk is either smaller or bigger than zero
      elsif Ops.less_than(address_2_1, 0) || Ops.greater_than(address_2_1, 0)
        # bigger means that the IP range is correct
        range_status = Ops.greater_than(address_2_1, 0) 

        # if they are equal, check the very next chunk...
      elsif Ops.less_than(address_2_2, 0) || Ops.greater_than(address_2_2, 0)
        range_status = Ops.greater_than(address_2_2, 0)
      elsif Ops.less_than(address_2_3, 0) || Ops.greater_than(address_2_3, 0)
        range_status = Ops.greater_than(address_2_3, 0)
      elsif Ops.less_than(address_2_4, 0) || Ops.greater_than(address_2_4, 0)
        range_status = Ops.greater_than(address_2_4, 0) 

        # what else?
      else
        Builtins.y2error(
          "Unknown match IP: %1 Last: %2",
          ipv4_list,
          last_ip_list
        )
        range_status = false
      end

      range_status
    end

    def ValidateAddDNSRangeDialog(current_d_settings)
      ret = nil

      hostname_base = Convert.to_string(
        UI.QueryWidget(Id("hostname_base"), :Value)
      )
      Builtins.y2milestone("Entered hostname base: %1", hostname_base)

      # checking number of '%i' in the hostname base
      nr_hostname_base = hostname_base
      i_count = 0
      while Builtins.regexpmatch(nr_hostname_base, "%i")
        i_count = Ops.add(i_count, 1)
        nr_hostname_base = Builtins.regexpsub(
          nr_hostname_base,
          "(.*)%i(.*)",
          "\\1--\\2"
        )
      end
      if Ops.greater_than(i_count, 1)
        Report.Error(
          # TRANSLATORS: popup error '%i' is a special string, do not translate it, please
          _("There can be only one '%i' in the hostname base string.")
        )
        return nil
      end
      nr_hostname_base = nil

      hostname_base_check = hostname_base
      if hostname_base_check != "" && hostname_base_check != nil
        # integer listed
        if Builtins.regexpmatch(hostname_base_check, "%i")
          hostname_base_check = Builtins.regexpsub(
            hostname_base_check,
            "^(.*)%i(.*)",
            "\\10\\2"
          ) 
          # add something
        else
          hostname_base_check = Ops.add(hostname_base_check, "0")
        end

        hostname_base_check = Punycode.EncodeDomainName(hostname_base_check)
      end

      Builtins.y2milestone("Checking hostname base: %1", hostname_base_check)

      # Checking the hostname base
      if hostname_base_check == "" || hostname_base_check == nil ||
          !Hostname.Check(hostname_base_check)
        UI.SetFocus(Id("hostname_base"))
        # TRANSLATORS: popup error, followed by a newline and a valid hostname description
        Report.Error(
          Ops.add(_("Invalid hostname.") + "\n\n", Hostname.ValidHost)
        )
        return nil
      end

      first_ip = Convert.to_string(UI.QueryWidget(Id("first_ip"), :Value))
      if !IP.Check4(first_ip)
        UI.SetFocus(Id("first_ip"))
        # TRANSLATORS: popup error, followed by a newline and a valid IPv4 description
        Report.Error(Ops.add(_("Invalid IP address.") + "\n\n", IP.Valid4))
        return nil
      end

      if !IPisInRangeOfIPs(
          first_ip,
          Ops.get(current_d_settings.value, "ipv4_min", ""),
          Ops.get(current_d_settings.value, "ipv4_max", "")
        )
        Report.Error(
          Builtins.sformat(
            # TRANSLATORS: popup error, %1 is an IP address
            # %2 is the first IP address of the range, %3 is the last one
            _(
              "IP address %1 is not in the range of allowed\nIP addresses (%2-%3) defined in the DHCP server.\n"
            ),
            first_ip,
            Ops.get(current_d_settings.value, "ipv4_min", ""),
            Ops.get(current_d_settings.value, "ipv4_max", "")
          )
        )
        return nil
      end

      last_ip = Convert.to_string(UI.QueryWidget(Id("last_ip"), :Value))
      if !IP.Check4(last_ip)
        UI.SetFocus(Id("last_ip"))
        # TRANSLATORS: popup error, followed by a newline and a valid IPv4 description
        Report.Error(Ops.add(_("Invalid IP address.") + "\n\n", IP.Valid4))
        return nil
      end

      if !IPisInRangeOfIPs(
          last_ip,
          Ops.get(current_d_settings.value, "ipv4_min", ""),
          Ops.get(current_d_settings.value, "ipv4_max", "")
        )
        Report.Error(
          Builtins.sformat(
            # TRANSLATORS: popup error, %1 is an IP address
            # %2 is the first IP address of the range, %3 is the last one
            _(
              "IP address %1 is not in the range of allowed\nIP addresses (%2-%3) defined in the DHCP server.\n"
            ),
            first_ip,
            Ops.get(current_d_settings.value, "ipv4_min", ""),
            Ops.get(current_d_settings.value, "ipv4_max", "")
          )
        )
        return nil
      end

      hostname_start_s = Convert.to_string(
        UI.QueryWidget(Id("hostname_start"), :Value)
      )
      hostname_start = 0
      if Builtins.regexpmatch(hostname_start_s, "^[0123456789]+$")
        hostname_start = Builtins.tointeger(hostname_start_s)
      end

      if !(
          current_d_settings_ref = arg_ref(current_d_settings.value);
          _CheckDNSRange_result = CheckDNSRange(
            first_ip,
            last_ip,
            current_d_settings_ref
          );
          current_d_settings.value = current_d_settings_ref.value;
          _CheckDNSRange_result
        )
        return nil
      end

      ret = {
        "hostname_base"  => hostname_base,
        "hostname_start" => hostname_start,
        "first_ip"       => first_ip,
        "last_ip"        => last_ip
      }

      deep_copy(ret)
    end









    def AddDNSRangeWorker(domain, hostname_domain, record_type, hostname_base, hostname_start, first_ip, last_ip)
      if !Builtins.contains(["A", "PTR"], record_type)
        Builtins.y2error(
          "Record type %1 is not handled by this function",
          record_type
        )
        return false
      end

      if Builtins.regexpmatch(hostname_base, "%i")
        hostname_base = Builtins.regexpsub(
          hostname_base,
          "^(.*)%i(.*)",
          "\\1%1\\2"
        )
      else
        hostname_base = Ops.add(hostname_base, "%1")
      end
      Builtins.y2milestone("Hostname base: %1", hostname_base)

      hostname_start = 0 if hostname_start == nil

      first_ip_list = Builtins.maplist(Builtins.splitstring(first_ip, ".")) do |ip_part|
        Builtins.tointeger(ip_part)
      end
      last_ip_list = Builtins.maplist(Builtins.splitstring(last_ip, ".")) do |ip_part|
        Builtins.tointeger(ip_part)
      end
      Builtins.y2milestone("Creating range: %1 - %2", first_ip, last_ip)

      # list of hostnames for next punycode translation
      hostnames = []
      # list of IPs matching these hostnames (by index)
      ips = []

      hostname_counter = Ops.subtract(hostname_start, 1)
      index_counter = -1

      # for counting max numbers
      to_2 = nil
      to_3 = nil
      to_4 = nil

      # Generating hostnames and IPs
      while Ops.less_or_equal(
          Ops.get(first_ip_list, 0, 1),
          Ops.get(last_ip_list, 0, 0)
        )
        # Range (1).1.1.1 -> (2).1.1.1
        #           contains (1).254.254.254
        if Ops.less_than(
            Ops.get(first_ip_list, 0, 1),
            Ops.get(last_ip_list, 0, 0)
          )
          to_2 = 254
        else
          to_2 = Ops.get(last_ip_list, 1, 0)
        end
        while Ops.less_or_equal(Ops.get(first_ip_list, 1, 1), to_2)
          # Range 1.(1).1.1 -> 1.(2).1.1
          #           contains 1.(1).254.254
          if Ops.less_than(
              Ops.get(first_ip_list, 1, 1),
              Ops.get(last_ip_list, 1, 0)
            )
            to_3 = 254
          else
            to_3 = Ops.get(last_ip_list, 2, 0)
          end
          while Ops.less_or_equal(Ops.get(first_ip_list, 2, 1), to_3)
            # Range 1.1.(1).1 -> 1.1.(2).1
            #           contains 1.1.(1).254
            if Ops.less_than(
                Ops.get(first_ip_list, 2, 1),
                Ops.get(last_ip_list, 2, 0)
              )
              to_4 = 254
            else
              to_4 = Ops.get(last_ip_list, 3, 0)
            end
            while Ops.less_or_equal(Ops.get(first_ip_list, 3, 1), to_4)
              # 0 at the end of IP address means network
              # skip it!
              if Ops.get(first_ip_list, 3) == 0
                Builtins.y2milestone("Skipping %1", first_ip_list)
                Ops.set(
                  first_ip_list,
                  3,
                  Ops.add(Ops.get(first_ip_list, 3, 0), 1)
                )
                next
              end

              hostname_counter = Ops.add(hostname_counter, 1)
              index_counter = Ops.add(index_counter, 1)

              Ops.set(
                hostnames,
                index_counter,
                Builtins.sformat(hostname_base, hostname_counter)
              )

              if record_type == "A"
                Ops.set(
                  ips,
                  index_counter,
                  Builtins.sformat(
                    "%1.%2.%3.%4",
                    Ops.get(first_ip_list, 0, 0),
                    Ops.get(first_ip_list, 1, 0),
                    Ops.get(first_ip_list, 2, 0),
                    Ops.get(first_ip_list, 3, 0)
                  )
                )
              elsif record_type == "PTR"
                Ops.set(
                  ips,
                  index_counter,
                  Builtins.sformat(
                    "%1.%2.%3.%4.in-addr.arpa.",
                    Ops.get(first_ip_list, 3, 0),
                    Ops.get(first_ip_list, 2, 0),
                    Ops.get(first_ip_list, 1, 0),
                    Ops.get(first_ip_list, 0, 0)
                  )
                )
              end
              Ops.set(
                first_ip_list,
                3,
                Ops.add(Ops.get(first_ip_list, 3, 0), 1)
              )
            end
            Ops.set(first_ip_list, 2, Ops.add(Ops.get(first_ip_list, 2, 0), 1))
            Ops.set(first_ip_list, 3, 0)
          end
          Ops.set(first_ip_list, 1, Ops.add(Ops.get(first_ip_list, 1, 0), 1))
          Ops.set(first_ip_list, 2, 0)
        end
        Ops.set(first_ip_list, 1, 0)
        Ops.set(first_ip_list, 0, Ops.add(Ops.get(first_ip_list, 0, 0), 1))
      end

      # Writing records into the DNS Server
      if Ops.greater_than(hostname_counter, 0)
        hostnames = Punycode.EncodePunycodes(hostnames)

        index_counter = -1
        Builtins.foreach(hostnames) do |one_hostname|
          index_counter = Ops.add(index_counter, 1)
          if record_type == "A"
            DnsServerAPI.AddZoneRR(
              domain,
              "A",
              one_hostname,
              Ops.get(ips, index_counter, "")
            )
          elsif record_type == "PTR"
            DnsServerAPI.AddZoneRR(
              domain,
              "PTR",
              Ops.get(ips, index_counter, ""),
              Ops.add(Ops.add(Ops.add(one_hostname, "."), hostname_domain), ".")
            )
          end
        end
      end

      true
    end
  end
end
