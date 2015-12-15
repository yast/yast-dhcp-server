# encoding: utf-8

# File:	include/dhcp-server/dns-server-management.ycp
# Package:	Configuration of dhcp-server
# Summary:	Synchronization with DNS Server
# Authors:	Lukas Ocilka <lukas.ocilka@suse.cz>
#
# $Id$
module Yast
  module DhcpServerDnsServerManagementInclude
    def initialize_dhcp_server_dns_server_management(include_target)
      Yast.import "UI"

      textdomain "dhcp-server"

      Yast.import "Wizard"
      Yast.import "DhcpServer"
      Yast.import "DnsServerAPI"
      Yast.import "DnsServer"
      Yast.import "Report"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "Punycode"
      Yast.import "Confirm"
      Yast.import "IP"
      Yast.import "Hostname"

      Yast.include include_target, "dhcp-server/dns-helps.rb"
      Yast.include include_target, "dhcp-server/dns-server-dialogs.rb"
      Yast.include include_target, "dhcp-server/dns-server-wizard.rb"

      @modified = false

      @dns_server_managed_records = []

      #
      # **Structure:**
      #
      #     $[
      #          "current_network" : "192.168.0.0",
      #          "domain"          : "example.com",
      #          "from_ip"         : "192.168.10.2",
      #          "to_ip"           : "192.168.15.254"
      #          "ipv4_max"        : "192.168.13.254",
      #          "ipv4_min"        : "192.168.0.1",
      #          "netmask"         : "255.255.240.0",
      #          "netmask_bits"    : "20",
      #          "network"         : "192.168.0.0",
      #          "network_binary"  : "11000000101010000000000000000000",
      #      ]
      @current_settings = {}
    end

    # --> Helper Functions

    def GetModified
      @modified
    end

    def SetModified
      @modified = true

      nil
    end

    def ResetModified
      @modified = false

      nil
    end

    # Converts DNS record to relative one
    def ToRelativeName(absolute_name, zone_name)
      return nil if absolute_name == nil || zone_name == nil

      remove_this_to_be_relative = Ops.add(Ops.add(".", zone_name), ".")
      relative_name = Builtins.regexpsub(
        absolute_name,
        Ops.add("(.*)", remove_this_to_be_relative),
        "\\1"
      )
      if relative_name != nil && !Builtins.regexpmatch(relative_name, "\\.")
        return relative_name
      end

      absolute_name
    end

    # <-- Helper Functions

    # --> Add / Delete - DNS Functions

    def RemoveDNSRangeWorker(first_ip, last_ip)
      zone_name = Ops.get(@current_settings, "domain", "")

      hostname = nil
      ipv4 = nil

      removed = 0
      all_zones = DnsServer.FetchZones

      zone_counter = -1
      zone_found = false

      Builtins.foreach(all_zones) do |one_zone|
        zone_counter = Ops.add(zone_counter, 1)
        if Ops.get(one_zone, "zone") == zone_name
          zone_found = true
          raise Break
        end
      end
      Builtins.y2error("Cannot find zone %1", zone_name) if !zone_found

      zone_records = Ops.get_list(all_zones, [zone_counter, "records"], [])

      # Filter out DNS records that match the rule
      zone_records = Builtins.filter(zone_records) do |one_record|
        # Only "A"
        next true if Ops.get(one_record, "type", "") != "A"
        hostname = Ops.get(one_record, "key", "")
        ipv4 = Ops.get(one_record, "value", "")
        # Only non-empty "key" and "value"
        next true if hostname == "" || ipv4 == ""
        if !IP.Check4(ipv4)
          # leaving wrong definition in the zone
          Builtins.y2warning("Not a valid IP '%1'", ipv4)
          next true
        end
        # Current IP doesn't match the range
        next true if !IPisInRangeOfIPs(ipv4, first_ip, last_ip)
        # Remove from zone
        removed = Ops.add(removed, 1)
        false
      end

      Ops.set(all_zones, [zone_counter, "records"], zone_records)

      DnsServer.StoreZones(all_zones)

      Ops.greater_than(removed, 0)
    end

    # <-- Add / Delete - DNS Functions

    # --> Edit Zone

    def RedrawRRsTable
      zone_name = Ops.get(@current_settings, "domain", "")

      zone_records = DnsServerAPI.GetZoneRRs(zone_name)

      # show the dialog
      show_progress_dialog = Ops.get(zone_records, 200) != nil
      # TRANSLATORS: busy message
      if show_progress_dialog
        UI.OpenDialog(Label(_("Regenerating DNS zone entries...")))
      end

      # later used when deleting records
      @dns_server_managed_records = []

      punycode_translations = []
      counter = -1
      record_key = ""
      zone_records = Builtins.filter(zone_records) do |one_record|
        record_key = ToRelativeName(Ops.get(one_record, "key", ""), zone_name)
        # record for the entire zone
        if Ops.get(one_record, "key", "") == Ops.add(zone_name, ".")
          record_key = ""
        end
        # Only "A" records and non-empty "key"
        if Ops.get(one_record, "type") == "A" && record_key != "" &&
            record_key != nil
          counter = Ops.add(counter, 1)
          Ops.set(punycode_translations, counter, record_key)
          Ops.set(
            @dns_server_managed_records,
            counter,
            { "name" => record_key, "ip" => Ops.get(one_record, "value", "") }
          )

          next true
        else
          next false
        end
      end

      punycode_translations = Punycode.DocodeDomainNames(punycode_translations)

      counter = -1
      items = Builtins.maplist(zone_records) do |one_record|
        counter = Ops.add(counter, 1)
        Item(
          Id(counter),
          Ops.get(punycode_translations, counter, ""),
          Ops.get(one_record, "value", "")
        )
      end

      # Free Willy!
      zone_records = []
      punycode_translations = []

      # progress dialog
      UI.CloseDialog if show_progress_dialog

      items = Builtins.sort(items) do |x, y|
        Ops.less_than(Ops.get_string(x, 1, ""), Ops.get_string(y, 1, ""))
      end
      UI.ChangeWidget(Id("zone_table"), :Items, items)

      nil
    end

    def AddDNSDialog
      UI.OpenDialog(
        VBox(
          MarginBox(
            1,
            1,
            Frame(
              # TRANSLATORS: dialog frame label
              _("Adding a New DNS Record"),
              VBox(
                # TRANSLATORS: text entry
                TextEntry(Id("new_hostname"), _("&Hostname")),
                # TRANSLATORS: text entry
                TextEntry(Id("new_ip"), _("&IP Address"))
              )
            )
          ),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(Id("new_ip"), :ValidChars, IP.ValidChars4)

      func_ret = false
      ret = nil
      while true
        ret = UI.UserInput

        if ret == :ok
          new_hostname = Convert.to_string(
            UI.QueryWidget(Id("new_hostname"), :Value)
          )
          new_hostname = Punycode.EncodeDomainName(new_hostname)
          if !Hostname.Check(new_hostname)
            UI.SetFocus(Id("new_hostname"))
            # TRANSLATORS: popup error, followed by a newline and a valid hostname description
            Report.Error(
              Ops.add(_("Invalid hostname.") + "\n\n", Hostname.ValidHost)
            )
            next
          end

          new_ip = Convert.to_string(UI.QueryWidget(Id("new_ip"), :Value))
          if !IP.Check4(new_ip)
            UI.SetFocus(Id("new_ip"))
            # TRANSLATORS: poupu error, followed by a newlone and a valid IPv4 description
            Report.Error(Ops.add(_("Invalid IP address.") + "\n\n", IP.Valid4))
            next
          end

          func_ret = DnsServerAPI.AddZoneRR(
            Ops.get(@current_settings, "domain", ""),
            "A",
            new_hostname,
            new_ip
          )
          SetModified()

          break
        else
          break
        end
      end

      UI.CloseDialog
      func_ret
    end

    def AddDNSRangeDialog
      # from shared dialogs
      CreateUI_DNSRangeDialog(
        Ops.get(@current_settings, "from_ip", ""),
        Ops.get(@current_settings, "to_ip", ""),
        {}
      )

      func_ret = false
      ret = nil
      while true
        ret = UI.UserInput

        if ret == :ok
          validated = (
            current_settings_ref = arg_ref(@current_settings);
            _ValidateAddDNSRangeDialog_result = ValidateAddDNSRangeDialog(
              current_settings_ref
            );
            @current_settings = current_settings_ref.value;
            _ValidateAddDNSRangeDialog_result
          )

          next if validated == nil

          UI.OpenDialog(
            Label(
              Builtins.sformat(
                # TRANSLATORS: busy message
                # %1 is the first IP address of the range, %2 is the last one
                _("Adding DHCP range %1-%2 to the DNS server..."),
                Ops.get_string(validated, "first_ip", ""),
                Ops.get_string(validated, "last_ip", "")
              )
            )
          )
          func_ret = AddDNSRangeWorker(
            Ops.get(@current_settings, "domain", ""),
            Ops.get(@current_settings, "domain", ""),
            "A", # adding 'A' records
            Ops.get_string(validated, "hostname_base", ""),
            Ops.get_integer(validated, "hostname_start", 1),
            Ops.get_string(validated, "first_ip", ""),
            Ops.get_string(validated, "last_ip", "")
          )
          SetModified()
          UI.CloseDialog

          break
        else
          break
        end
      end

      UI.CloseDialog
      func_ret
    end

    def RemoveDNSRangeDialog
      UI.OpenDialog(
        VBox(
          MarginBox(
            1,
            1,
            Frame(
              # TRANSLATORS: dialog frame label
              _("Removing DNS Records Matching Range"),
              HBox(
                # TRANSLATORS: text entry
                HWeight(1, TextEntry(Id("first_ip"), _("&First IP Address"))),
                # TRANSLATORS: text entry
                HWeight(1, TextEntry(Id("last_ip"), _("&Last IP Address")))
              )
            )
          ),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(Id("first_ip"), :ValidChars, IP.ValidChars4)
      UI.ChangeWidget(Id("last_ip"), :ValidChars, IP.ValidChars4)

      # Predefining initial values
      UI.ChangeWidget(
        Id("first_ip"),
        :Value,
        Ops.get(@current_settings, "from_ip", "")
      )
      UI.ChangeWidget(
        Id("last_ip"),
        :Value,
        Ops.get(@current_settings, "to_ip", "")
      )

      func_ret = false
      ret = nil
      while true
        ret = UI.UserInput

        if ret == :ok
          first_ip = Convert.to_string(UI.QueryWidget(Id("first_ip"), :Value))
          if !IP.Check4(first_ip)
            UI.SetFocus(Id("first_ip"))
            # TRANSLATORS: popup error, followed by a newline and a valid IPv4 description
            Report.Error(Ops.add(_("Invalid IP address.") + "\n\n", IP.Valid4))
            next
          end

          last_ip = Convert.to_string(UI.QueryWidget(Id("last_ip"), :Value))
          if !IP.Check4(last_ip)
            UI.SetFocus(Id("last_ip"))
            # TRANSLATORS: popup error, followed by a newline and a valid IPv4 description
            Report.Error(Ops.add(_("Invalid IP address.") + "\n\n", IP.Valid4))
            next
          end

          # Checking delta between first_ip and last_ip
          first_ip_list = Builtins.maplist(Builtins.splitstring(first_ip, ".")) do |ip_part|
            Builtins.tointeger(ip_part)
          end
          last_ip_list = Builtins.maplist(Builtins.splitstring(last_ip, ".")) do |ip_part|
            Builtins.tointeger(ip_part)
          end

          # Computing deltas
          # 195(.168.0.1) - 192(.11.0.58) => 3
          address_1 = Ops.subtract(
            Ops.get(last_ip_list, 0, 0),
            Ops.get(first_ip_list, 0, 0)
          )
          address_2 = Ops.subtract(
            Ops.get(last_ip_list, 1, 0),
            Ops.get(first_ip_list, 1, 0)
          )
          address_3 = Ops.subtract(
            Ops.get(last_ip_list, 2, 0),
            Ops.get(first_ip_list, 2, 0)
          )
          address_4 = Ops.subtract(
            Ops.get(last_ip_list, 3, 0),
            Ops.get(first_ip_list, 3, 0)
          )

          range_status = nil
          # first chunk is either smaller or bigger than zero
          if Ops.less_than(address_1, 0) || Ops.greater_than(address_1, 0)
            # bigger means that the IP range is correct
            range_status = Ops.greater_than(address_1, 0) 

            # if they are equal, check the very next chunk...
          elsif Ops.less_than(address_2, 0) || Ops.greater_than(address_2, 0)
            range_status = Ops.greater_than(address_2, 0)
          elsif Ops.less_than(address_3, 0) || Ops.greater_than(address_3, 0)
            range_status = Ops.greater_than(address_3, 0)
          elsif Ops.less_than(address_4, 0) || Ops.greater_than(address_4, 0)
            range_status = Ops.greater_than(address_4, 0) 

            # addresses are the same
          else
            range_status = false
          end

          if !range_status
            # TRANSLATORS: popup error
            Report.Error(
              _("The last IP address must be higher than the first one.")
            )
            next
          end

          UI.OpenDialog(
            Label(
              Builtins.sformat(
                # TRANSLATORS: busy message
                # %1 is the first IP address of the range, %2 is the last one
                _("Removing records in the range %1-%2 from the DNS server..."),
                first_ip,
                last_ip
              )
            )
          )
          Builtins.y2milestone("Removing DNS range %1 - %2", first_ip, last_ip)
          func_ret = RemoveDNSRangeWorker(first_ip, last_ip)
          UI.CloseDialog

          break
        else
          break
        end
      end

      UI.CloseDialog
      func_ret == false ? false : true
    end

    def DeleteDNSDialog
      current_item = Convert.to_integer(
        UI.QueryWidget(Id("zone_table"), :CurrentItem)
      )
      return nil if current_item == nil

      return nil if !Confirm.DeleteSelected

      delete_item = Ops.get(@dns_server_managed_records, current_item, {})
      success = DnsServerAPI.RemoveZoneRR(
        Ops.get(@current_settings, "domain", ""),
        "A",
        Ops.get(delete_item, "name", ""),
        Ops.get(delete_item, "ip", "")
      )
      SetModified()
      Builtins.y2milestone(
        "Removing: %1 / %2 from %3 -> %4",
        Ops.get(delete_item, "name", ""),
        Ops.get(delete_item, "ip", ""),
        Ops.get(@current_settings, "domain", ""),
        success
      )

      RedrawRRsTable()

      nil
    end

    def CheckDNSZone
      Builtins.y2error("FIXME: !!!!!!!!!!!!!")
      nil
    end

    def RunDNSWizardFromScratch
      ret = RunNewDNSServerWizard(@current_settings)

      if ret == :next
        SetModified()
        return true
      end

      false
    end

    def HandleSyncRZCheckbox
      current_status = Convert.to_boolean(
        UI.QueryWidget(Id(:sync_reverse_zone), :Value)
      )
      # do not sync
      return nil if !current_status

      rs_master = IsDNSZoneMaster(
        Ops.get(@current_settings, "reverse_domain", "")
      )
      if rs_master == true
        Builtins.y2milestone(
          "Zone %1 will be synchornized with %2",
          Ops.get(@current_settings, "reverse_domain", ""),
          Ops.get(@current_settings, "domain", "")
        )
        SetModified()
        return 

        #
      elsif rs_master == false
        UI.ChangeWidget(Id(:sync_reverse_zone), :Value, false)
        Report.Error(
          Builtins.sformat(
            # TRANSLATORS: popup error, %1 is the zone name
            # please, do not translate 'master' (exact DNS definition)
            _(
              "Zone %1 is not of the type master.\nThe DNS server cannot write any records to it.\n"
            ),
            Ops.get(@current_settings, "reverse_domain", "")
          )
        )
        return 

        # zone doesn't exist
      else
        # should we create that zone?
        if Popup.YesNo(
            Builtins.sformat(
              # TRANSLATORS: popup question, %1 is a DNS zone name
              _(
                "Zone %1 does not yet exist in the current DNS server configuration.\nCreate it?\n"
              ),
              Ops.get(@current_settings, "reverse_domain", "")
            )
          )
          Builtins.y2milestone(
            "Creating zone reverse %1",
            Ops.get(@current_settings, "reverse_domain", "")
          )
          DnsServerAPI.AddZone(
            Ops.get(@current_settings, "reverse_domain", ""),
            "master",
            {}
          )
          if !IsDNSZoneMaster(Ops.get(@current_settings, "reverse_domain", ""))
            UI.ChangeWidget(Id(:sync_reverse_zone), :Value, false)
            Report.Error(
              Builtins.sformat(
                # TRANSLATORS: popup error, %1 is a zone name
                _("Cannot create zone %1."),
                Ops.get(@current_settings, "reverse_domain", "")
              )
            )
          else
            SetModified()
          end
          return
        else
          Builtins.y2milestone(
            "user decided not to create reverse zone %1",
            Ops.get(@current_settings, "reverse_domain", "")
          )
          UI.ChangeWidget(Id(:sync_reverse_zone), :Value, false)
          return
        end
      end
    end

    def GetZoneRecords(zone_name)
      if zone_name == nil || zone_name == ""
        Builtins.y2error("Zone name not set")
        return nil
      end

      ret = nil
      Builtins.foreach(DnsServer.FetchZones) do |zone|
        if Ops.get_string(zone, "zone", "") == zone_name
          ret = Ops.get_list(zone, "records", [])
          raise Break
        end
      end

      deep_copy(ret)
    end

    def SetZoneRecords(zone_name, new_records)
      if zone_name == nil || zone_name == ""
        Builtins.y2error("Zone name not set")
        return nil
      end

      all_records = DnsServer.FetchZones

      zone_counter = -1
      Builtins.foreach(all_records) do |zone|
        zone_counter = Ops.add(zone_counter, 1)
        # zone match found
        raise Break if Ops.get_string(zone, "zone", "") == zone_name
      end

      if Ops.greater_than(zone_counter, -1)
        Ops.set(all_records, [zone_counter, "records"], new_records.value)
        DnsServer.StoreZones(all_records)
      end

      nil
    end

    def SynchronizeReverseZone
      # reverse zone
      r_zone = Ops.get(@current_settings, "reverse_domain")
      if r_zone == nil
        Builtins.y2error("No reverse zone defined")
        return false
      end

      # base zone
      b_zone = Ops.get(@current_settings, "domain")
      if b_zone == nil
        Builtins.y2error("No base zone defined")
        return false
      end

      Builtins.y2milestone("Synchronizing %1 with %2", r_zone, b_zone)

      # remove all NS records from the current zone
      Builtins.foreach(DnsServerAPI.GetZoneNameServers(r_zone)) do |zone_ns|
        DnsServerAPI.RemoveZoneNameServer(r_zone, zone_ns)
      end

      # add all NS records from the base zone
      Builtins.foreach(DnsServerAPI.GetZoneNameServers(b_zone)) do |zone_ns|
        # reletive vs. absolute NS name
        if !Builtins.regexpmatch(zone_ns, ".$")
          zone_ns = Ops.add(Ops.add(Ops.add(zone_ns, "."), b_zone), ".")
        end
        Builtins.y2milestone("Adding NS %1 into %2", zone_ns, r_zone)
        DnsServerAPI.AddZoneNameServer(r_zone, zone_ns)
      end

      # minimal and maximal DHCP addresses
      dhcp_min_ip = Ops.get(@current_settings, "from_ip")
      dhcp_max_ip = Ops.get(@current_settings, "to_ip")

      zone_records_r = GetZoneRecords(r_zone)

      Builtins.y2milestone(
        "Filtering out records from range %1 - %2",
        dhcp_min_ip,
        dhcp_max_ip
      )
      # remove all PTR records from the current DHCP range
      zone_records_r = Builtins.filter(zone_records_r) do |zone_record|
        # leave all non-PTR records
        next true if Ops.get(zone_record, "type", "") != "PTR"
        # relative name 15.5 vs. absolute  15.5.168.192.in-addr.arpa.
        if !Builtins.regexpmatch(Ops.get(zone_record, "key", ""), ".$")
          Ops.set(
            zone_record,
            "key",
            Ops.add(
              Ops.add(Ops.add(Ops.get(zone_record, "key", ""), "."), r_zone),
              "."
            )
          )
        end
        r_ip2 = Builtins.splitstring(Ops.get(zone_record, "key", ""), ".")
        # unknown record, leave it there
        if Builtins.size(r_ip2) != 7
          Builtins.y2warning("Unknown record %1", zone_record)
          next true
        end
        ip_b = Builtins.sformat(
          "%1.%2.%3.%4",
          Ops.get(r_ip2, 3, "x"),
          Ops.get(r_ip2, 2, "x"),
          Ops.get(r_ip2, 1, "x"),
          Ops.get(r_ip2, 0, "x")
        )
        # wrong IP, leave it there
        if !IP.Check4(ip_b)
          Builtins.y2warning("Wrong IP %1 (%2)", ip_b, zone_record)
          next true
        end
        # IP matches the range
        next false if IPisInRangeOfIPs(ip_b, dhcp_min_ip, dhcp_max_ip)
        # Any other record
        true
      end

      zone_records_b = GetZoneRecords(b_zone)

      hostname = nil
      r_ip_l = nil
      r_ip = nil

      # starts with 0 (if no entries)
      record_counter = Builtins.size(zone_records_r)

      Builtins.y2milestone("Synchronizing A records to reverse zone...")
      # add all A records from the base zone as PTR records
      Builtins.foreach(zone_records_b) do |zone_record|
        # not an 'A' record
        next if Ops.get(zone_record, "type", "") != "A"
        # wrong IP
        if !IP.Check4(Ops.get(zone_record, "value", ""))
          Builtins.y2warning(
            "Invalid IPv4 %1",
            Ops.get(zone_record, "value", "")
          )
          next
        end
        # IP doesn't match the DHCP range
        if !IPisInRangeOfIPs(
            Ops.get(zone_record, "value", ""),
            dhcp_min_ip,
            dhcp_max_ip
          )
          next
        end
        # convert IP to reverseIP
        r_ip_l = Builtins.splitstring(Ops.get(zone_record, "value", ""), ".")
        r_ip = Builtins.sformat(
          "%1.%2.%3.%4.in-addr.arpa.",
          Ops.get(r_ip_l, 3, "x"),
          Ops.get(r_ip_l, 2, "x"),
          Ops.get(r_ip_l, 1, "x"),
          Ops.get(r_ip_l, 0, "x")
        )
        # convert relative hostname to absolute one
        hostname = Ops.get(zone_record, "key", "")
        if !Builtins.regexpmatch(hostname, "\\.$")
          hostname = Ops.add(Ops.add(Ops.add(hostname, "."), b_zone), ".")
        end
        # Last check
        if r_ip == "" || hostname == ""
          Builtins.y2error(
            "Wrong IP/Hostname %1/%2 (%3)",
            r_ip,
            hostname,
            zone_record
          )
          next
        end
        # Adding new record
        Ops.set(
          zone_records_r,
          record_counter,
          { "key" => r_ip, "type" => "PTR", "value" => hostname }
        )
        record_counter = Ops.add(record_counter, 1)
      end

      zone_records_r_ref = arg_ref(zone_records_r)
      SetZoneRecords(r_zone, zone_records_r_ref)
      zone_records_r = zone_records_r_ref.value
      Builtins.y2milestone("Synchronized")

      true
    end

    def SynchronizeReverseZoneDialog
      if !UI.WidgetExists(Id(:sync_reverse_zone))
        Builtins.y2warning("No such widget: %1", :sync_reverse_zone)
        return nil
      end

      # do not synchornize
      if !Convert.to_boolean(UI.QueryWidget(Id(:sync_reverse_zone), :Value))
        return true
      end

      # TRANSLATORS: busy message
      UI.OpenDialog(Label(_("Synchronizing DNS reverse records...")))
      ret = SynchronizeReverseZone()
      UI.CloseDialog

      ret
    end

    # Returns whether the DNS Should be stored
    # or reverted back
    def HandleDNSDialog
      dialog_ret = true

      ret = nil
      while true
        event = UI.WaitForEvent
        ret = Ops.get_symbol(event, "ID")

        # Timeout
        if ret == :timeout
          next 

          # [ OK ] or [ Next ]
        elsif ret == :ok || ret == :next
          # synchronizing on exit
          SynchronizeReverseZoneDialog()
          dialog_ret = true
          break 

          # Adding new record
        elsif ret == :add
          RedrawRRsTable() if AddDNSDialog()
          next
        elsif ret == :delete
          DeleteDNSDialog()
          next 

          # [ Cancel ] or [ Back ]
        elsif ret == :cancel || ret == :back
          if !GetModified()
            dialog_ret = true
            break
          end

          # TRANSLATORS: popup question - canceling dns synchronization with dhcp
          if Popup.YesNo(
              _(
                "If you cancel, all changes made to the DNS server will be lost.\nReally cancel this operation?\n"
              )
            )
            # Changes currently made will be reverted
            Builtins.y2milestone(
              "Cancel... Recent changes in DNS will be reverted"
            )
            dialog_ret = false
            break
          else
            next
          end 

          # Adding DHCP Range
        elsif ret == :add_range
          RedrawRRsTable() if AddDNSRangeDialog()
          next 

          # Checking the zone and reporting result
        elsif ret == :check_zone
          CheckDNSZone() 

          # Removing all A records with IPs that match the current range
        elsif ret == :remove_range
          RedrawRRsTable() if RemoveDNSRangeDialog() 

          # Running a Wizard Sequence (Editing zone from scratch)
        elsif ret == :run_wizard
          RedrawRRsTable() if RunDNSWizardFromScratch() 

          # Synchronize with Reverse Zone (checkbox changed)
        elsif ret == :sync_reverse_zone
          HandleSyncRZCheckbox() 

          # the rest
        else
          Builtins.y2error("Unknown input: %1", ret)
          next
        end
      end

      dialog_ret
    end

    def DNSServerDialogContents
      VBox(
        HBox(
          # TRANSLATORS: text entry
          TextEntry(Id("current_zone"), _("&Domain")),
          # TRANSLATORS: text entry
          TextEntry(Id("current_network"), _("&Network")),
          # TRANSLATORS: text entry
          TextEntry(Id("current_netmask"), _("Net&mask"))
        ),
        HBox(
          # TRANSLATORS: text entry
          HWeight(1, TextEntry(Id("info_min_ip"), _("&First IP Address"))),
          # TRANSLATORS: text entry
          HWeight(1, TextEntry(Id("info_max_ip"), _("&Last IP Address"))),
          HWeight(1, Empty())
        ),
        # TRANSLATORS: table label
        Left(Label(_("DNS Zone Records"))),
        Table(
          Id("zone_table"),
          Header(
            # TRANSLATORS: table header item
            _("Hostname"),
            # TRANSLATORS: table header item
            _("Assigned IP")
          ),
          []
        ),
        ReplacePoint(Id("sync_also_reverse_zone"), Empty()),
        HBox(
          # TRANSLATORS: push button
          PushButton(Id(:add), _("&Add...")),
          HSpacing(1),
          # TRANSLATORS: push button
          PushButton(Id(:delete), Label.DeleteButton),
          HSpacing(1),
          MenuButton(
            Id("dns_menu"),
            # TRANSLATORS: menu button
            _("&Special Tasks"),
            # FIXME: add functionality (dialog) for checking the zone
            # such as missing NS server, range of dhcp clients that are not mentioned
            # in the DNS, etc...
            # // TRANSLATORS: menu entry
            # `item (`id (`check_zone),   _("Check Zone"))
            [
              # TRANSLATORS: menu entry
              Item(Id(:add_range), _("Add New Range of DNS Records")),
              # TRANSLATORS: menu entry
              Item(Id(:remove_range), _("Removing DNS Records Matching Range")),
              # TRANSLATORS: menu entry
              Item(
                Id(:run_wizard),
                _("Run Wizard to Rewrite the DNS Zone from Scratch")
              )
            ]
          )
        )
      )
    end

    # Init DNS / DHCP Dialog
    def InitDNSServerConfiguration(current_settings)
      current_settings = deep_copy(current_settings)
      Builtins.y2milestone("%1", current_settings)

      UI.ChangeWidget(
        Id("current_zone"),
        :Value,
        Ops.get(current_settings, "domain", "")
      )
      UI.ChangeWidget(
        Id("current_network"),
        :Value,
        Ops.get(current_settings, "current_network", "")
      )
      UI.ChangeWidget(
        Id("current_netmask"),
        :Value,
        Ops.get(current_settings, "netmask", "")
      )
      UI.ChangeWidget(
        Id("info_min_ip"),
        :Value,
        Ops.get(current_settings, "from_ip", "")
      )
      UI.ChangeWidget(
        Id("info_max_ip"),
        :Value,
        Ops.get(current_settings, "to_ip", "")
      )

      UI.ChangeWidget(Id("current_zone"), :Enabled, false)
      UI.ChangeWidget(Id("current_network"), :Enabled, false)
      UI.ChangeWidget(Id("current_netmask"), :Enabled, false)
      UI.ChangeWidget(Id("info_min_ip"), :Enabled, false)
      UI.ChangeWidget(Id("info_max_ip"), :Enabled, false)

      # reverse domain is set
      if Ops.get(current_settings, "reverse_domain", "") != ""
        rd_enabled = true
        rd_selected = true

        is_master = IsDNSZoneMaster(
          Ops.get(current_settings, "reverse_domain", "")
        )
        # exists as a master
        if is_master == true
          rd_enabled = true
          rd_selected = true 
          # exists but not as a master
        elsif is_master == false
          rd_enabled = false
          rd_selected = false 
          # doesn't exist
        else
          rd_enabled = true
          rd_selected = false
        end

        reverse_zone_checkbox = CheckBox(
          Id(:sync_reverse_zone),
          Opt(:notify),
          Builtins.sformat(
            # TRANSLATORS: checkbox, %1 is a zone name
            _("Synchronize with Reverse Zone %1"),
            Ops.get(current_settings, "reverse_domain", "")
          ),
          rd_selected
        )
        UI.ReplaceWidget(
          Id("sync_also_reverse_zone"),
          VBox(VSpacing(0.3), reverse_zone_checkbox, VSpacing(1))
        )
        UI.ChangeWidget(Id(:sync_reverse_zone), :Enabled, false) if !rd_enabled
      end

      nil
    end

    # Checks whether the current zone is maintained by the DNS Server (master)
    # Initializes zone records and lists them in the table
    #
    def InitZoneRecords(zone_name)
      all_zones = DnsServerAPI.GetZones

      if Ops.get(all_zones, zone_name) == nil
        Builtins.y2error(
          "Zone %1 is not maintained by this DNS Server, cannot edit...",
          zone_name
        )

        return false
      end

      if Ops.get(all_zones, ["zone_name", "type"], "master") != "master"
        Builtins.y2error(
          "Zone %1 is type %2",
          zone_name,
          Ops.get(all_zones, ["zone_name", "type"])
        )

        return false
      end

      Builtins.y2milestone("Zone '%1' editable, initializing...", zone_name)
      RedrawRRsTable()

      true
    end

    # Manages the synchronization with DNS Server
    def ManageDNSServer(param_current_settings)
      param_current_settings = deep_copy(param_current_settings)
      # init the internal variable
      @current_settings = deep_copy(param_current_settings)

      # TRANSLATORS: dialog caption
      caption = _("DHCP Server: DNS Server Synchronization")

      Wizard.CreateDialog
      Wizard.HideAbortButton

      Wizard.SetContentsButtons(
        caption,
        DNSServerDialogContents(),
        Ops.get(@DNS_HELPS, "edit-current-settings", ""),
        Label.CancelButton,
        Label.OKButton
      )
      Wizard.SetDesktopTitleAndIcon("dhcp-server")

      InitDNSServerConfiguration(@current_settings)

      if InitZoneRecords(Ops.get(@current_settings, "domain", ""))
        # Save the current DNS configuration before editing
        saved_conf = DnsServer.Export

        if !HandleDNSDialog()
          Builtins.y2milestone(
            "Reverting changes made in DNS Server by DHCP Server"
          )
          DnsServer.Import(saved_conf)
        end
      else
        Builtins.y2milestone(
          "Unable to continue, returning back from DNS Dialog..."
        )
      end

      Wizard.CloseDialog
      true
    end
  end
end
