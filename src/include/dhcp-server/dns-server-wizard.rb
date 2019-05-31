# encoding: utf-8

# File:	include/dhcp-server/dns-server-management.ycp
# Package:	Configuration of dhcp-server
# Summary:	Synchronization with DNS Server
# Authors:	Lukas Ocilka <lukas.ocilka@suse.cz>
#
# $Id$
module Yast
  module DhcpServerDnsServerWizardInclude
    def initialize_dhcp_server_dns_server_wizard(include_target)
      Yast.import "UI"

      textdomain "dhcp-server"

      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "DnsServer"
      Yast.import "DnsServerAPI"
      Yast.import "Punycode"
      Yast.import "IP"
      Yast.import "Hostname"
      Yast.import "Sequencer"
      Yast.import "Report"
      Yast.import "Popup"

      Yast.include include_target, "dhcp-server/dns-helps.rb"
      Yast.include include_target, "dhcp-server/dns-server-dialogs.rb"

      # *********************************************************************

      # --> Internal Variables

      # used for checking, informin about minimal and maximal values, etc.
      @current_dhcp_settings = {}

      # contains configuration of the new zone(s)
      @create_new_zone = {}

      # used for editing or removing current nameservers
      @translated_nameservers = {}

      # used for editing or removing current ranges
      @used_ranges = []
    end

    # <-- Internal Variables

    # *********************************************************************

    # --> Helper functions

    def AbortWizard
      Popup.YesNoHeadline(
        # TRANSLATORS: Popup headline
        _("Aborting the Wizard"),
        # TRANSLATORS: Popup question
        _("All changes made in the wizard will be lost.\nReally abort?\n")
      )
    end

    def Wizard_StoreNewZoneDialog
      # sets whether the reverse zone will be created too
      Ops.set(
        @create_new_zone,
        "create_reverse_zone",
        Convert.to_boolean(
          UI.QueryWidget(Id(:create_also_reverse_zone), :Value)
        )
      )

      nil
    end

    def Wizard_DeleteNSDialog
      row_id = Convert.to_string(
        UI.QueryWidget(Id("name_servers"), :CurrentItem)
      )

      selected_ns = Ops.get(@translated_nameservers, [row_id, 1], "")
      selected_ip = Ops.get(@translated_nameservers, [row_id, 2], "")

      Ops.set(
        @create_new_zone,
        "name_servers",
        Builtins.filter(Ops.get_list(@create_new_zone, "name_servers", [])) do |one|
          Ops.get(one, 0, "") != selected_ns ||
            Ops.get(one, 1, "") != selected_ip
        end
      )

      true
    end

    def Wizard_DeleteResourceRecordsDialogDialog
      row_id = Convert.to_integer(
        UI.QueryWidget(Id("dhcp_records"), :CurrentItem)
      )
      filter_range = Ops.get(@used_ranges, row_id, {})

      Ops.set(
        @create_new_zone,
        "ranges",
        Builtins.filter(Ops.get_list(@create_new_zone, "ranges", [])) do |one|
          Ops.get_string(one, "base", "") !=
            Ops.get_string(filter_range, "base", "") ||
            Ops.get_integer(one, "start", 1) !=
              Ops.get_integer(filter_range, "start", 1) ||
            Ops.get_string(one, "from", "") !=
              Ops.get_string(filter_range, "from", "") ||
            Ops.get_string(one, "to", "") !=
              Ops.get_string(filter_range, "to", "")
        end
      )

      true
    end

    def Wizard_AddEditNSDialog(edit_current_ns)
      # TRANSLATORS: dialog frame label
      frame_label = _("Add a New Name Server")
      selected_ns = ""
      selected_ns_encoded = ""
      selected_ip = ""

      if edit_current_ns
        # TRANSLATORS: dialgo frame label
        frame_label = _("Edit Name Server")

        row_id = Convert.to_string(
          UI.QueryWidget(Id("name_servers"), :CurrentItem)
        )

        selected_ns = Ops.get(@translated_nameservers, [row_id, 0], "")
        selected_ns_encoded = Ops.get(@translated_nameservers, [row_id, 1], "") # actually the same as 'row_id'
        selected_ip = Ops.get(@translated_nameservers, [row_id, 2], "")
      end

      UI.OpenDialog(
        VBox(
          MarginBox(
            1,
            1,
            Frame(
              frame_label,
              VBox(
                # TRANSLATORS: text entry
                TextEntry(Id("nameserver"), _("&Hostname"), selected_ns),
                # TRANSLATORS: text entry
                TextEntry(Id("ip"), _("Server &IP"), selected_ip)
              )
            )
          ),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )
      UI.ChangeWidget(Id("ip"), :ValidChars, IP.ValidChars4)

      ret_val = false
      ret = nil
      while true
        ret = UI.UserInput

        if ret == :cancel
          ret_val = false
          break
        elsif ret == :ok
          # new values
          new_selected_ns = Convert.to_string(
            UI.QueryWidget(Id("nameserver"), :Value)
          )
          new_selected_ip = Convert.to_string(UI.QueryWidget(Id("ip"), :Value))

          if new_selected_ns != ""
            new_selected_ns = Punycode.EncodeDomainName(new_selected_ns)
          end

          # Hostname with a dot at the end is not a valid hostname
          # but it's needed for DNS Server
          hostname_check = new_selected_ns
          if Builtins.regexpmatch(hostname_check, ".$")
            hostname_check = Builtins.regexpsub(hostname_check, "(.*).$", "\\1")
          end

          if !Hostname.CheckDomain(hostname_check)
            UI.SetFocus(Id("nameserver"))
            Report.Error(
              Ops.add("Invalid hostname." + "\n\n", Hostname.ValidDomain)
            )
            # next UserInput
            next
          end

          # not a final dot
          if !Builtins.regexpmatch(new_selected_ns, "\\.$")
            # absolute name, add a dot
            if Builtins.regexpmatch(new_selected_ns, "\\.")
              new_selected_ns = Ops.add(new_selected_ns, ".") 
              # relative name, add a domain name
            else
              new_selected_ns = Ops.add(
                Ops.add(
                  Ops.add(new_selected_ns, "."),
                  Ops.get(@current_dhcp_settings, "domain", "")
                ),
                "."
              )
            end
          end

          # IP is only optional
          if new_selected_ip != "" && !IP.Check4(new_selected_ip)
            UI.SetFocus(Id("ip"))
            Report.Error(Ops.add("Invalid IP address." + "\n\n", IP.Valid4))
            # next UserInput
            next
          end

          # IP is optional when the server is external
          if new_selected_ip == "" &&
              Builtins.regexpmatch(
                new_selected_ns,
                Ops.add(
                  Ops.add(".", Ops.get(@current_dhcp_settings, "domain", "")),
                  ".$"
                )
              )
            UI.SetFocus(Id("ip"))
            # TRANSLATORS: popup question
            if !Popup.YesNo(
                _(
                  "No IP address has been provided for a name server in the current DNS zone.\n" +
                    "This may not work because each zone needs the name and IP of its name server defined. \n" +
                    "Really use the current settings?\n"
                )
              )
              next
            end
          end

          # changing server name from
          # check whether the new already exists or not
          if selected_ns_encoded != new_selected_ns
            found_match = false
            Builtins.foreach(Ops.get_list(@create_new_zone, "name_servers", [])) do |one|
              # nameserver already exists in the configuration
              if Ops.get(one, 0, "") == new_selected_ns
                found_match = true
                Report.Error(
                  Builtins.sformat(
                    # TRANSLATORS: popup error, %1 si a server name
                    _("Name server %1 already exists in the configuration."),
                    new_selected_ns
                  )
                )
                raise Break
              end
            end
            # next UserInput
            next if found_match
          end

          # in case of `edit
          Ops.set(
            @create_new_zone,
            "name_servers",
            Builtins.filter(Ops.get_list(@create_new_zone, "name_servers", [])) do |one|
              Ops.get(one, 0, "") != selected_ns_encoded ||
                Ops.get(one, 1, "") != selected_ip
            end
          )

          Ops.set(
            @create_new_zone,
            "name_servers",
            Builtins.add(
              Ops.get_list(@create_new_zone, "name_servers", []),
              [new_selected_ns, new_selected_ip]
            )
          )

          ret_val = true

          break
        end
      end

      UI.CloseDialog

      ret_val
    end

    def CheckRangeAgainsAllRanges(new_range, all_ranges)
      all_ranges = deep_copy(all_ranges)
      ret = true

      new_range_from = Ops.get_string(new_range.value, "from", "")
      new_range_to = Ops.get_string(new_range.value, "to", "")

      if new_range_from == "" || new_range_to == ""
        Builtins.y2error("Wrong definition of new range: %1", new_range.value)
        return false
      end

      # $[ "base":"dhcp-%i", "from":"192.168.10.1", "start":1, "to":"192.168.10.254" ]
      Builtins.foreach(all_ranges) do |one_range|
        range_from = Ops.get_string(one_range, "from", "")
        range_to = Ops.get_string(one_range, "to", "")
        if IPisInRangeOfIPs(new_range_from, range_from, range_to) ||
            IPisInRangeOfIPs(new_range_to, range_from, range_to)
          if Popup.YesNo(
              Builtins.sformat(
                # TRANSLATORS: popup error
                # %1 the first IP address og 'another range'
                # %2 is the last one
                _(
                  "This new range of DNS entries is already covered by\n" +
                    "another one (%1-%2).\n" +
                    "Really use the new one?\n"
                ),
                Ops.get_string(one_range, "from", ""),
                Ops.get_string(one_range, "to", "")
              )
            )
            ret = true
            raise Break
          else
            ret = false
            raise Break
          end
        end
      end

      ret
    end

    def Wizard_AddEditResourceRecordsDialog(edit_current_rr)
      old_range = {}

      if edit_current_rr
        row_id = Convert.to_integer(
          UI.QueryWidget(Id("dhcp_records"), :CurrentItem)
        )

        old_range = Ops.get(@used_ranges, row_id, {})
      end

      # opens a dialog
      CreateUI_DNSRangeDialog(
        Ops.get(@current_dhcp_settings, "from_ip", ""),
        Ops.get(@current_dhcp_settings, "to_ip", ""),
        old_range
      )

      func_ret = false
      ret = nil
      while true
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :cancel
          func_ret = false
          break
        elsif ret == :ok
          # working with this map only (in this block)
          current_ranges = Ops.get_list(@create_new_zone, "ranges", [])

          validated = (
            current_dhcp_settings_ref = arg_ref(@current_dhcp_settings);
            _ValidateAddDNSRangeDialog_result = ValidateAddDNSRangeDialog(
              current_dhcp_settings_ref
            );
            @current_dhcp_settings = current_dhcp_settings_ref.value;
            _ValidateAddDNSRangeDialog_result
          )
          next if validated == nil

          # map with new range
          new_range = {
            "base"  => Ops.get_string(validated, "hostname_base", ""),
            "start" => Ops.get_integer(validated, "hostname_start", 1),
            "from"  => Ops.get_string(validated, "first_ip", ""),
            "to"    => Ops.get_string(validated, "last_ip", "")
          }

          # filter out old range (in case of edit)
          current_ranges = Builtins.filter(current_ranges) do |one|
            Ops.get_string(one, "base", "") != Ops.get(old_range, "base") ||
              Ops.get_integer(one, "start", 1) != Ops.get(old_range, "start") ||
              Ops.get_string(one, "from", "") != Ops.get(old_range, "from") ||
              Ops.get_string(one, "to", "") != Ops.get(old_range, "to")
          end if old_range != {}

          # Checks whether a new range doesn't conflict with another one
          if !(
              new_range_ref = arg_ref(new_range);
              _CheckRangeAgainsAllRanges_result = CheckRangeAgainsAllRanges(
                new_range_ref,
                current_ranges
              );
              new_range = new_range_ref.value;
              _CheckRangeAgainsAllRanges_result
            )
            # cancelled, add the filtered-out range again
            current_ranges = Builtins.add(current_ranges, old_range)
            next
          end

          # Adding new range definition
          current_ranges = Builtins.add(current_ranges, new_range)

          func_ret = true
          Ops.set(@create_new_zone, "ranges", current_ranges)

          break
        end
      end

      UI.CloseDialog

      func_ret
    end

    def CheckNumberOfNameServers
      if Builtins.size(Ops.get_list(@create_new_zone, "name_servers", [])) == 0
        Report.Error(_("At least one name server must be defined."))

        return false
      end

      true
    end

    # <-- Helper functions

    # *********************************************************************

    # --> Definition of Dialogs

    def Wizard_CreateNewZoneDialog
      # TRANSLATORS: a dialog caption
      caption = _("DHCP Server: New DNS Zone--Step 1 of 3")

      contents = VBox(
        Left(
          HSquash(
            MinWidth(
              30,
              VBox(
                TextEntry(
                  Id("zone_name"),
                  # TRANSLATORS: text entry
                  _("New &Zone Name")
                ),
                TextEntry(
                  Id("current_network"),
                  # TRANSLATORS: text entry
                  _("&Current Network")
                ),
                VSpacing(1),
                Left(
                  CheckBox(
                    Id(:create_also_reverse_zone),
                    Opt(:notify),
                    # TRANSLATORS: check box
                    _("&Also Create Reverse Zone")
                  )
                ),
                ReplacePoint(Id("reverse_zone_rp"), Empty())
              )
            )
          )
        ),
        VStretch()
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get(@DNS_HELPS, "wizard-zones", ""),
        Label.BackButton,
        Label.NextButton
      )

      Wizard.DisableBackButton

      nil
    end

    def Wizard_CreateZoneNameServersDialog
      # TRANSLATORS: a dialog caption
      caption = _("DHCP Server: Zone Name Servers--Step 2 of 3")

      contents = VBox(
        Left(
          HSquash(
            MinWidth(
              30,
              VBox(
                TextEntry(
                  Id("zone_name"),
                  # TRANSLATORS: text entry
                  _("New &Zone Name")
                ),
                TextEntry(
                  Id("current_network"),
                  # TRANSLATORS: text entry
                  _("&Current Network")
                )
              )
            )
          )
        ),
        VSpacing(1),
        # TRANSLATORS: table label
        Left(Label(_("Current Name Servers"))),
        Table(
          Id("name_servers"),
          Header(
            # TRANSLATORS: table header item
            _("Server Name"),
            # TRANSLATORS: table header item
            _("IP (Optional)")
          ),
          []
        ),
        HBox(
          # TRANSLATORS: push button
          PushButton(Id(:add_ns), _("A&dd...")),
          # TRANSLATORS: push button
          PushButton(Id(:edit_ns), _("&Edit...")),
          PushButton(Id(:delete_ns), Label.DeleteButton)
        )
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get(@DNS_HELPS, "wizard-nameservers", ""),
        Label.BackButton,
        Label.NextButton
      )

      nil
    end

    def Wizard_CreateZoneResourceRecordsDialog
      # TRANSLATORS: a dialog caption
      caption = _("DHCP Server: DNS Records--Step 3 of 3")

      contents = VBox(
        Left(
          HSquash(
            MinWidth(
              30,
              VBox(
                TextEntry(
                  Id("zone_name"),
                  # TRANSLATORS: text entry
                  _("New &Zone Name")
                ),
                TextEntry(
                  Id("current_network"),
                  # TRANSLATORS: text entry
                  _("&Current Network")
                )
              )
            )
          )
        ),
        VSpacing(1),
        # TRANSLATORS: table header label
        Left(Label(_("DNS Records for DHCP Clients"))),
        Table(
          Id("dhcp_records"),
          Header(
            # TRANSLATORS: table header item
            _("Hostname Base"),
            # TRANSLATORS: table header item
            _("Number to Start With"),
            # TRANSLATORS: table header item
            _("From IP"),
            # TRANSLATORS: table header item
            _("To IP")
          ),
          []
        ),
        HBox(
          # TRANSLATORS: push button
          PushButton(Id(:add_dhcp), _("A&dd...")),
          # TRANSLATORS: push button
          PushButton(Id(:edit_dhcp), _("&Edit...")),
          PushButton(Id(:delete_dhcp), Label.DeleteButton)
        )
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get(@DNS_HELPS, "wizard-ranges", ""),
        Label.BackButton,
        Label.NextButton
      )

      nil
    end

    def Wizard_CreateNewZoneSummaryDialog
      # TRANSLATORS: a dialog caption
      caption = _("DHCP Server: DNS Records--Summary")

      contents = VBox(RichText(Id("summary"), ""))

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get(@DNS_HELPS, "wizard-summary", ""),
        Label.BackButton,
        Label.FinishButton
      )

      nil
    end

    # <-- Definition of Dialogs

    # *********************************************************************

    # Init Dialog Functions -->

    def Wizard_InitNewZoneDialog_ReverseZone
      # reverse zone is selected to be created
      if Ops.get_boolean(@create_new_zone, "create_reverse_zone", false) == true
        UI.ReplaceWidget(
          Id("reverse_zone_rp"),
          TextEntry(
            Id("reverse_zone_name"),
            # TRANSLATORS: text entry
            _("Re&verse Zone Name"),
            Ops.get(@current_dhcp_settings, "reverse_domain", "")
          )
        )
        UI.ChangeWidget(Id("reverse_zone_name"), :Enabled, false)
      else
        UI.ReplaceWidget(Id("reverse_zone_rp"), Empty())
      end

      nil
    end

    def Wizard_InitNewZoneDialog
      UI.ChangeWidget(
        Id("zone_name"),
        :Value,
        Ops.get(@current_dhcp_settings, "domain", "")
      )
      UI.ChangeWidget(
        Id("current_network"),
        :Value,
        Builtins.sformat(
          "%1 / %2",
          Ops.get(@current_dhcp_settings, "current_network", ""),
          Ops.get(@current_dhcp_settings, "netmask", "")
        )
      )

      UI.ChangeWidget(Id("zone_name"), :Enabled, false)
      UI.ChangeWidget(Id("current_network"), :Enabled, false)

      # init the current checkbox value
      UI.ChangeWidget(
        Id(:create_also_reverse_zone),
        :Value,
        Ops.get_boolean(@create_new_zone, "create_reverse_zone", false) == true
      )
      # disable the checkbox if reverse_domain is not defined
      if Ops.get(@current_dhcp_settings, "reverse_domain", "") == ""
        UI.ChangeWidget(Id(:create_also_reverse_zone), :Enabled, false)
      end

      Wizard_InitNewZoneDialog_ReverseZone()

      nil
    end

    def Wizard_InitZoneNameServersDialog
      UI.ChangeWidget(
        Id("zone_name"),
        :Value,
        Ops.get(@current_dhcp_settings, "domain", "")
      )
      UI.ChangeWidget(
        Id("current_network"),
        :Value,
        Builtins.sformat(
          "%1 / %2",
          Ops.get(@current_dhcp_settings, "current_network", ""),
          Ops.get(@current_dhcp_settings, "netmask", "")
        )
      )

      UI.ChangeWidget(Id("zone_name"), :Enabled, false)
      UI.ChangeWidget(Id("current_network"), :Enabled, false)

      # sorts punycode instead of decoded strings
      Ops.set(
        @create_new_zone,
        "name_servers",
        Builtins.sort(Ops.get_list(@create_new_zone, "name_servers", [])) do |x, y|
          Ops.less_than(Ops.get(x, 0, ""), Ops.get(y, 0, ""))
        end
      )

      strings_to_translate = []
      counter = -1
      Builtins.foreach(Ops.get_list(@create_new_zone, "name_servers", [])) do |one_ns|
        counter = Ops.add(counter, 1)
        Ops.set(strings_to_translate, counter, Ops.get(one_ns, 0, ""))
      end

      if Ops.greater_than(counter, -1)
        strings_to_translate = Punycode.DocodeDomainNames(strings_to_translate)

        counter = -1
        table_items = Builtins.maplist(
          Ops.get_list(@create_new_zone, "name_servers", [])
        ) do |one_ns|
          counter = Ops.add(counter, 1)
          Ops.set(
            @translated_nameservers,
            Ops.get(one_ns, 0, ""),
            [
              Ops.get(strings_to_translate, counter, ""),
              Ops.get(one_ns, 0, ""),
              Ops.get(one_ns, 1, "")
            ]
          )
          Item(
            Id(Ops.get(one_ns, 0, "")),
            Ops.get(strings_to_translate, counter, ""),
            Ops.get(one_ns, 1, "")
          )
        end

        UI.ChangeWidget(Id("name_servers"), :Items, table_items)

        UI.ChangeWidget(Id(:edit_ns), :Enabled, true)
        UI.ChangeWidget(Id(:delete_ns), :Enabled, true)
      else
        UI.ChangeWidget(Id(:edit_ns), :Enabled, false)
        UI.ChangeWidget(Id(:delete_ns), :Enabled, false)

        UI.ChangeWidget(Id("name_servers"), :Items, [])
      end

      nil
    end

    def Wizard_InitZoneResourceRecordsDialog
      UI.ChangeWidget(
        Id("zone_name"),
        :Value,
        Ops.get(@current_dhcp_settings, "domain", "")
      )
      UI.ChangeWidget(
        Id("current_network"),
        :Value,
        Builtins.sformat(
          "%1 / %2",
          Ops.get(@current_dhcp_settings, "current_network", ""),
          Ops.get(@current_dhcp_settings, "netmask", "")
        )
      )

      UI.ChangeWidget(Id("zone_name"), :Enabled, false)
      UI.ChangeWidget(Id("current_network"), :Enabled, false)

      counter = -1
      basenames = Builtins.maplist(Ops.get_list(@create_new_zone, "ranges", [])) do |one_range|
        counter = Ops.add(counter, 1)
        Builtins.tostring(Ops.get_string(one_range, "base", ""))
      end
      if Ops.greater_than(counter, -1)
        basenames = Punycode.DecodePunycodes(basenames)
      end

      counter = -1
      items = Builtins.maplist(Ops.get_list(@create_new_zone, "ranges", [])) do |one_range|
        counter = Ops.add(counter, 1)
        Ops.set(
          @used_ranges,
          counter,
          {
            "base"  => Ops.get_string(one_range, "base", ""),
            "start" => Ops.get_integer(one_range, "start", 1),
            "from"  => Ops.get_string(one_range, "from", ""),
            "to"    => Ops.get_string(one_range, "to", "")
          }
        )
        Item(
          Id(counter),
          Ops.get(basenames, counter, ""),
          Ops.get_integer(one_range, "start", 1),
          Ops.get_string(one_range, "from", ""),
          Ops.get_string(one_range, "to", "")
        )
      end

      items = Builtins.sort(items) do |x, y|
        Ops.less_than(Ops.get_string(x, 3, ""), Ops.get_string(y, 3, ""))
      end
      UI.ChangeWidget(Id("dhcp_records"), :Items, items)

      if Ops.greater_than(counter, -1)
        UI.ChangeWidget(Id(:edit_dhcp), :Enabled, true)
        UI.ChangeWidget(Id(:delete_dhcp), :Enabled, true)
      else
        UI.ChangeWidget(Id(:edit_dhcp), :Enabled, false)
        UI.ChangeWidget(Id(:delete_dhcp), :Enabled, false)
      end

      nil
    end

    def Wizard_InitNewZoneSummaryDialog
      summary = ""

      # zone name
      summary = Ops.add(
        Ops.add(summary, "<p>"),
        Builtins.sformat(
          # TRANSLATORS: HTML summary item
          _("<b>Zone Name:</b> %1"),
          Ops.get(@current_dhcp_settings, "domain", "")
        )
      )

      if IsDNSZoneMaintained(Ops.get(@current_dhcp_settings, "domain"))
        # TRANSLATORS: HTML summary item
        summary = Ops.add(
          Ops.add(summary, " "),
          _("(Replacing the current zone with the new one)")
        )
      end

      summary = Ops.add(summary, "</p>\n")

      # reverse zone name
      if Ops.get_boolean(@create_new_zone, "create_reverse_zone", true)
        summary = Ops.add(
          Ops.add(summary, "<p>"),
          Builtins.sformat(
            # TRANSLATORS: HTML summary item
            _("<b>Reverse Zone Name:</b> %1"),
            Ops.get(@current_dhcp_settings, "reverse_domain", "")
          )
        )

        if IsDNSZoneMaintained(
            Ops.get(@current_dhcp_settings, "reverse_domain")
          )
          # TRANSLATORS: HTML summary note
          summary = Ops.add(
            Ops.add(summary, " "),
            _("(Replacing the current zone with the new one)")
          )
        end

        summary = Ops.add(summary, "</p>\n")
      end

      # name servers
      # TRANSLATORS: html summary header
      summary = Ops.add(
        Ops.add(Ops.add(summary, "<p><b>"), _("Zone Name Servers:")),
        "</b><ul>\n"
      )
      Builtins.foreach(Ops.get_list(@create_new_zone, "name_servers", [])) do |ns|
        summary = Ops.add(
          Ops.add(
            Ops.add(summary, "<li>"),
            Builtins.sformat(
              # TRANSLATORS: HTML summary item, %1 is a hostname, %2 is an IP address
              _("Hostname: %1, IP: %2"),
              Ops.get(ns, 0, ""),
              # TRANSLATORS: IP address for the HTML summary item is not defined
              Ops.get(ns, 1, "") == "" ? _("Not defined") : Ops.get(ns, 1, "")
            )
          ),
          "</li>\n"
        )
      end
      summary = Ops.add(summary, "</ul></p>\n")

      # dhcp ranges
      # TRANSLATORS: HTML summary header
      summary = Ops.add(
        Ops.add(Ops.add(summary, "<p><b>"), _("Ranges of DNS Hosts:")),
        "</b><ul>\n"
      )
      Builtins.foreach(Ops.get_list(@create_new_zone, "ranges", [])) do |range|
        summary = Ops.add(
          Ops.add(
            Ops.add(summary, "<li>"),
            Builtins.sformat(
              # TRANSLATORS: HTML summary item
              # %1 is the first IP of the range, %2 is the last one
              # %3 defines the hostname base (e.g., 'dhcp-%i')
              # %4 is a number 'start' used incremental replacement for '%i'
              _("Range: %1-%2<br />Hostname Base: %3, Starting With: %4"),
              Ops.get_string(range, "from", ""),
              Ops.get_string(range, "to", ""),
              Ops.get_string(range, "base", ""),
              Ops.get_integer(range, "start", 1)
            )
          ),
          "</li>\n"
        )
      end
      summary = Ops.add(summary, "</ul></p>\n")

      UI.ChangeWidget(Id("summary"), :Value, summary)

      nil
    end

    # <-- Init Dialog Functions

    # *********************************************************************

    # --> Wizard Dialogs

    def Wizard_NewZoneDialog
      Wizard_CreateNewZoneDialog()
      Wizard_InitNewZoneDialog()

      ret = nil
      while true
        ret = UI.UserInput

        Builtins.y2milestone("Ret: %1", ret)

        if ret == :next
          Wizard_StoreNewZoneDialog()
          break
        elsif ret == :create_also_reverse_zone
          Wizard_StoreNewZoneDialog()
          Wizard_InitNewZoneDialog_ReverseZone()
        elsif ret == :abort
          break if AbortWizard()
        else
          Builtins.y2error("Unexpected ret: %1", ret)
        end
      end

      Convert.to_symbol(ret)
    end

    def Wizard_ZoneNameServersDialog
      Wizard_CreateZoneNameServersDialog()
      Wizard_InitZoneNameServersDialog()

      ret = nil
      while true
        ret = UI.UserInput

        Builtins.y2milestone("Ret: %1", ret)

        if ret == :next
          if CheckNumberOfNameServers()
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :add_ns
          Wizard_InitZoneNameServersDialog() if Wizard_AddEditNSDialog(false)
        elsif ret == :edit_ns
          Wizard_InitZoneNameServersDialog() if Wizard_AddEditNSDialog(true)
        elsif ret == :delete_ns
          Wizard_InitZoneNameServersDialog() if Wizard_DeleteNSDialog()
        elsif ret == :abort
          break if AbortWizard()
        else
          Builtins.y2error("Unexpecetd ret: %1", ret)
        end
      end

      # free the memory
      @translated_nameservers = {}

      Convert.to_symbol(ret)
    end

    def Wizard_ZoneResourceRecordsDialog
      Wizard_CreateZoneResourceRecordsDialog()
      Wizard_InitZoneResourceRecordsDialog()

      ret = nil
      while true
        ret = UI.UserInput

        Builtins.y2milestone("Ret: %1", ret)

        if ret == :next
          if Builtins.size(Ops.get_list(@create_new_zone, "ranges", [])) == 0
            # TRANSLATORS: popup error
            Report.Error(_("At least one DNS record must be set."))
            next
          end
          break
        elsif ret == :back
          break
        elsif ret == :add_dhcp
          if Wizard_AddEditResourceRecordsDialog(false)
            Wizard_InitZoneResourceRecordsDialog()
          end
        elsif ret == :edit_dhcp
          if Wizard_AddEditResourceRecordsDialog(true)
            Wizard_InitZoneResourceRecordsDialog()
          end
        elsif ret == :delete_dhcp
          if Wizard_DeleteResourceRecordsDialogDialog()
            Wizard_InitZoneResourceRecordsDialog()
          end
        elsif ret == :abort
          break if AbortWizard()
        else
          Builtins.y2error("Unexpected ret: %1", ret)
        end
      end

      # free the memory
      @used_ranges = []

      Convert.to_symbol(ret)
    end

    def Wizard_NewZoneSummaryDialog
      Wizard_CreateNewZoneSummaryDialog()
      Wizard_InitNewZoneSummaryDialog()

      ret = nil
      while true
        ret = UI.UserInput

        if ret == :next
          break
        elsif ret == :back
          break
        elsif ret == :abort
          break if AbortWizard()
        else
          Builtins.y2error("Unexpected ret: %1", ret)
        end
      end

      Convert.to_symbol(ret)
    end

    # <-- Wizard Dialogs

    # *********************************************************************

    # --> Creating Zones

    def CreateDNSZonesAndFillThemUp
      errors = ""

      zone = Ops.get(@current_dhcp_settings, "domain", "")

      # Base Zone
      # Remove Base zone if exists
      Builtins.y2milestone("Creating zone: %1", zone)
      if IsDNSZoneMaintained(zone)
        Builtins.y2milestone("Removing zone %1", zone)
        DnsServerAPI.RemoveZone(zone)
        if IsDNSZoneMaintained(zone)
          errors = Ops.add(
            Ops.add(
              errors,
              Builtins.sformat(
                # TRANSLATORS: error message, %1 is a zone name
                _("Cannot remove zone %1."),
                zone
              )
            ),
            "\n"
          )
          Builtins.y2error("Cannot remove zone %1", zone)

          return errors
        end
      end

      # Create Base zone
      DnsServerAPI.AddZone(zone, "master", {})
      if !IsDNSZoneMaintained(zone)
        errors = Ops.add(
          Ops.add(
            errors,
            Builtins.sformat(
              # TRANSLATORS: error message, %1 is a zone name
              _("Cannot create zone %1."),
              zone
            )
          ),
          "\n"
        )
        Builtins.y2error("Cannot create zone %1", zone)

        return errors
      end

      # Add Name Servers
      Builtins.foreach(Ops.get_list(@create_new_zone, "name_servers", [])) do |one_ns|
        Builtins.y2milestone(
          "Adding NS record: %1 into %2",
          Ops.get(one_ns, 0, ""),
          zone
        )
        DnsServerAPI.AddZoneNameServer(zone, Ops.get(one_ns, 0, ""))
        if Ops.get(one_ns, 1, "") != "" &&
            Builtins.regexpmatch(
              Ops.get(one_ns, 0, ""),
              Ops.add(Ops.add(".", zone), ".$")
            )
          Builtins.y2milestone(
            "Adding A record for NS record (%1 -A-> %2)",
            Ops.get(one_ns, 0, ""),
            Ops.get(one_ns, 1, "")
          )
          DnsServerAPI.AddZoneRR(
            zone,
            "A",
            Ops.get(one_ns, 0, ""),
            Ops.get(one_ns, 1, "")
          )
        end
      end
      # Checking added name servers
      if Builtins.size(DnsServerAPI.GetZoneNameServers(zone)) !=
          Builtins.size(Ops.get_list(@create_new_zone, "name_servers", []))
        # TRANSLATORS: error message, %1 is a zone name
        errors = Ops.add(
          Ops.add(
            errors,
            Builtins.sformat(_("Cannot add name servers to zone %1."), zone)
          ),
          "\n"
        )
        return errors
      end

      # Create DHCPrange records
      some_errors = false
      Builtins.foreach(Ops.get_list(@create_new_zone, "ranges", [])) do |one_range|
        Builtins.y2milestone("Creating DNS Range: %1", one_range)
        if !AddDNSRangeWorker(
            zone,
            zone,
            "A",
            Ops.get_string(one_range, "base", ""),
            Ops.get_integer(one_range, "start", 1),
            Ops.get_string(one_range, "from", ""),
            Ops.get_string(one_range, "to", "")
          )
          # TRANSLATORS: error message
          errors = Ops.add(errors, _("Cannot add zone DNS records."))
          some_errors = true
          raise Break
        end
      end
      return errors if some_errors

      # Do not create reverse zone
      if !Ops.get_boolean(@create_new_zone, "create_reverse_zone", true)
        return errors
      end

      reverse_zone = Ops.get(@current_dhcp_settings, "reverse_domain", "")

      # Reverse Zone
      # Remove Reverse zone if exists
      if IsDNSZoneMaintained(reverse_zone)
        Builtins.y2milestone("Removing zone %1", reverse_zone)
        DnsServerAPI.RemoveZone(reverse_zone)
        if IsDNSZoneMaintained(reverse_zone)
          errors = Ops.add(
            Ops.add(
              errors,
              Builtins.sformat(
                # TRANSLATORS: error message, %1 is a reverse zone name
                _("Cannot remove zone %1."),
                reverse_zone
              )
            ),
            "\n"
          )
          Builtins.y2error("Cannot remove zone %1", reverse_zone)

          return errors
        end
      end

      # Create Reverse zone
      Builtins.y2milestone("Creating zone: %1", reverse_zone)
      DnsServerAPI.AddZone(reverse_zone, "master", {})
      if !IsDNSZoneMaintained(reverse_zone)
        errors = Ops.add(
          Ops.add(
            errors,
            Builtins.sformat(
              # TRANSLATORS: error message, %1 is a reverse zone name
              _("Cannot create reverse zone %1."),
              reverse_zone
            )
          ),
          "\n"
        )
        Builtins.y2error("Cannot create zone %1", reverse_zone)

        return errors
      end

      # Add Name Servers
      Builtins.foreach(Ops.get_list(@create_new_zone, "name_servers", [])) do |one_ns|
        Builtins.y2milestone(
          "Adding NS record: %1 into %2",
          Ops.get(one_ns, 0, ""),
          reverse_zone
        )
        DnsServerAPI.AddZoneNameServer(reverse_zone, Ops.get(one_ns, 0, "")) # A records were already added into the Base zone
      end
      # Checking added name servers
      if Builtins.size(DnsServerAPI.GetZoneNameServers(reverse_zone)) !=
          Builtins.size(Ops.get_list(@create_new_zone, "name_servers", []))
        # TRANSLATORS: error message, %1 is a zone name
        errors = Ops.add(
          Ops.add(
            errors,
            Builtins.sformat(
              _("Cannot add name servers to zone %1."),
              reverse_zone
            )
          ),
          "\n"
        )
        return errors
      end

      # Create DHCPrange Reverse records
      Builtins.foreach(Ops.get_list(@create_new_zone, "ranges", [])) do |one_range|
        Builtins.y2milestone("Creating DNS Range: %1", one_range)
        if !AddDNSRangeWorker(
            reverse_zone,
            zone,
            "PTR",
            Ops.get_string(one_range, "base", ""),
            Ops.get_integer(one_range, "start", 1),
            Ops.get_string(one_range, "from", ""),
            Ops.get_string(one_range, "to", "")
          )
          # TRANSLATORS: error message
          errors = Ops.add(errors, _("Cannot add zone DNS records."))
          some_errors = true
          raise Break
        end
      end

      errors
    end

    def Wizard_CreateZoneDialog
      # TRANSLATORS: busy message
      UI.OpenDialog(Label(_("Creating DNS zone...")))

      Builtins.y2milestone("Creating new zone... (backing-up old settings)")

      # backup old settings for now
      current_settings_save = DnsServer.Export

      ret = :next
      # Creating zones and records
      errors = CreateDNSZonesAndFillThemUp()

      UI.CloseDialog

      # Checking if successful
      if errors != ""
        # restore previous settings
        # TRANSLATORS: busy message
        UI.OpenDialog(Label(_("Restoring previous DNS settings...")))
        Builtins.y2milestone(
          "Creation failed, Restoring previous DNS settings..."
        )
        DnsServer.Import(current_settings_save)
        current_settings_save = {}
        UI.CloseDialog

        if Popup.YesNo(
            Builtins.sformat(
              # TRANSLATORS: popup question, %1 is a list of errors
              _(
                "Errors occurred during DNS zone creation:\n" +
                  "\n" +
                  "%1\n" +
                  "Return to the wizard?\n"
              ),
              errors
            )
          )
          Builtins.y2milestone("User decided to run through Wizard again")
          ret = :wizard_again
        else
          Builtins.y2milestone("User decided to leave the Wizard")
          ret = :next
        end
      else
        ret = :next
        Builtins.y2milestone("Creation was successful")
        # TRANSLATORS: popup message
        Report.Message(_("The DNS zone was created successfully."))
      end

      ret
    end

    # <-- Creating Zones

    # *********************************************************************

    # --> Wizard Workflow

    def RunNewDNSServerWizard(dhcp_settings)
      dhcp_settings = deep_copy(dhcp_settings)
      # internal client variable init
      @current_dhcp_settings = deep_copy(dhcp_settings)
      dhcp_settings = {}

      # init default values
      @create_new_zone = {
        # cannot create reverse domain if it is undefined
        "create_reverse_zone" => Ops.get(
          @current_dhcp_settings,
          "reverse_domain",
          ""
        ) != "",
        # [ $[ "ns1" : "192.168.0.1" ], ... ]
        "name_servers"        => [],
        # [ $[ "base" : "dhcp-%", "start" : 101, "from" : "192.168.10.1", "to" : "192.168.10.100" ], ... ]
        "ranges"              => []
      }

      Builtins.y2milestone("Known Settings: %1", @current_dhcp_settings)

      aliases = {
        "new_zone"          => lambda { Wizard_NewZoneDialog() },
        "zone_name_servers" => lambda { Wizard_ZoneNameServersDialog() },
        "zone_rrs"          => lambda { Wizard_ZoneResourceRecordsDialog() },
        "new_zone_summary"  => lambda { Wizard_NewZoneSummaryDialog() },
        "create_zone"       => lambda { Wizard_CreateZoneDialog() }
      }

      sequence = {
        "ws_start"          => "new_zone",
        "new_zone"          => {
          :abort => :abort,
          :next  => "zone_name_servers"
        },
        "zone_name_servers" => { :abort => :abort, :next => "zone_rrs" },
        "zone_rrs"          => { :abort => :abort, :next => "new_zone_summary" },
        "new_zone_summary"  => { :abort => :abort, :next => "create_zone" },
        "create_zone"       => {
          # if the creation fails, user can decide
          # to run through the Wizard again
          :wizard_again => "new_zone",
          :abort        => :abort,
          :next         => :next
        }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("org.openSUSE.YaST.DHCPServer")

      dns_server_settings = DnsServer.Export
      ret = Sequencer.Run(aliases, sequence)
      if ret != :next
        Builtins.y2milestone("Ret: %1, Restoring DNS Server settings...", ret)
        DnsServer.Import(dns_server_settings)
      end

      # free the memory
      @current_dhcp_settings = nil
      @create_new_zone = nil

      Wizard.CloseDialog

      ret
    end
  end
end
