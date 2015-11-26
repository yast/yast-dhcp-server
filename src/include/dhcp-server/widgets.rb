# encoding: utf-8

# File:	modules/DhcpServer.ycp
# Package:	Configuration of dhcp-server
# Summary:	Data for configuration of dhcp-server,
#              input and output functions.
# Authors:	Jiri Srain <jsrain@suse.cz>

require "yast"
require "ui/service_status"

# Representation of the configuration of dhcp-server.
# Input and output routines.
module Yast
  module DhcpServerWidgetsInclude
    def initialize_dhcp_server_widgets(include_target)
      textdomain "dhcp-server"

      Yast.import "CWM"
      Yast.import "CWMTsigKeys"
      Yast.import "DhcpServer"
      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "Label"
      Yast.import "LogView"
      Yast.import "Popup"
      Yast.import "TablePopup"
      Yast.import "SuSEFirewall"
      Yast.import "Mode"

      # Init ServiceStatus widget
      @service = SystemdService.find(DhcpServer.ServiceName())
      @status_widget = ::UI::ServiceStatus.new(@service, reload_label: :restart)
    end

    # Function for deleting entry from section
    # Used for all (global, host, subnet) section due to the same location
    #  of data
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @return [Boolean] true if was really deleted
    def commonTableEntryDelete(opt_id, key)
      opt_id = deep_copy(opt_id)
      return false if !Ops.is_string?(opt_id)
      index = Builtins.tointeger(
        Builtins.regexpsub(
          Convert.to_string(opt_id),
          "^[a-z]+ ([0-9]+)$",
          "\\1"
        )
      )
      if Builtins.substring(key, 0, 7) == "option "
        Ops.set(@current_entry_options, index, nil)
        @current_entry_options = Builtins.filter(@current_entry_options) do |o|
          o != nil
        end
      else
        Ops.set(@current_entry_directives, index, nil)
        @current_entry_directives = Builtins.filter(@current_entry_directives) do |d|
          d != nil
        end
      end
      true
    end

    # Create list of identifiers of etries that should be present in the table
    # @param [Hash] descr map description of the table
    # @return [Array] of identifiers of entries of the table
    def getTableContents(descr)
      descr = deep_copy(descr)
      index = -1
      opts = Builtins.maplist(@current_entry_options) do |m|
        index = Ops.add(index, 1)
        Builtins.sformat("option %1", index)
      end

      index = -1
      dirs = Builtins.maplist(@current_entry_directives) do |m|
        index = Ops.add(index, 1)
        if Ops.get_string(m, "key", "") != "zone"
          next Builtins.sformat("directive %1", index)
        end
        nil
      end
      Builtins.filter(
        Convert.convert(
          Builtins.merge(dirs, opts),
          :from => "list",
          :to   => "list <string>"
        )
      ) { |id| id != nil }
    end

    # Transform table entry id to option id
    # @param [Hash] table map table description
    # @param [Object] id any entry id
    # @return [String] option key
    def id2key(table, id)
      table = deep_copy(table)
      id = deep_copy(id)
      return "" if !Ops.is_string?(id)
      strid = Convert.to_string(id)
      if Builtins.substring(strid, 0, 7) == "option "
        index = Builtins.tointeger(Builtins.substring(strid, 7))
        return Builtins.sformat(
          "option %1",
          Ops.get(@current_entry_options, [index, "key"], "")
        )
      elsif Builtins.substring(strid, 0, 10) == "directive "
        index = Builtins.tointeger(Builtins.substring(strid, 10))
        return Ops.get(@current_entry_directives, [index, "key"], "")
      end
      strid
    end

    # Get the popup widget description map
    # @param [String] opt_key string option key
    # @return [Hash] popup description map
    def key2descr(opt_key)
      ret = Ops.get_map(@popups, opt_key)
      return deep_copy(ret) if ret != nil
      {
        "init"  => fun_ref(method(:commonPopupInit), "void (any, string)"),
        "store" => fun_ref(method(:commonPopupSave), "void (any, string)")
      }
    end

    # Get map of widget
    # @param [Array] add_values list of values to be offered via the add button
    # @return [Hash] of widget
    def getOptionsTableWidget(add_values)
      add_values = deep_copy(add_values)
      ret = TablePopup.CreateTableDescr(
        { "add_delete_buttons" => true, "up_down_buttons" => false },
        {
          "init"                 => fun_ref(
            TablePopup.method(:TableInitWrapper),
            "void (string)"
          ),
          "handle"               => fun_ref(
            TablePopup.method(:TableHandleWrapper),
            "symbol (string, map)"
          ),
          "options"              => @popups,
          "id2key"               => fun_ref(
            method(:id2key),
            "string (map, any)"
          ),
          "ids"                  => fun_ref(
            method(:getTableContents),
            "list (map)"
          ),
          "help"                 => Ops.get(@HELPS, "options_table", ""),
          "fallback"             => {
            "init"    => fun_ref(method(:commonPopupInit), "void (any, string)"),
            "store"   => fun_ref(method(:commonPopupSave), "void (any, string)"),
            "summary" => fun_ref(
              method(:commonTableEntrySummary),
              "string (any, string)"
            )
          },
          "option_delete"        => fun_ref(
            method(:commonTableEntryDelete),
            "boolean (any, string)"
          ),
          "add_items"            => add_values,
          "add_items_keep_order" => true
        }
      )
      deep_copy(ret)
    end


    # Ask for exit without saving
    # @return event that should be handled, nil if user canceled the exit
    def confirmAbort
      Popup.YesNo(
        # Yes-No popup
        _(
          "If you leave the DHCP server configuration without saving,\nall changes will be lost. Really leave?"
        )
      )
    end

    # Check whether settings were changed and if yes, ask for exit
    # without saving
    # @return event that should be handled, nil if user canceled the exit
    def confirmAbortIfChanged
      return true if !DhcpServer.GetModified
      confirmAbort
    end

    # chroot widget

    # Initialize the widget
    # @param [String] id any widget id
    def chrootInit(id)
      ss = DhcpServer.GetChrootJail
      UI.ChangeWidget(Id(id), :Value, ss)

      nil
    end

    # Store settings of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    def chrootStore(id, event)
      event = deep_copy(event)
      ss = Convert.to_boolean(UI.QueryWidget(Id(id), :Value))
      DhcpServer.SetChrootJail(ss)

      nil
    end

    # Handle function of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    # @return [Symbol] always nil
    def chrootHandle(id, event)
      event = deep_copy(event)
      start = Convert.to_boolean(UI.QueryWidget(Id(id), :Value))
      DhcpServer.SetModified if start != DhcpServer.GetChrootJail
      nil
    end

    # ldap widget

    # Initialize the widget
    # @param [String] id any widget id
    def ldapInit(id)
      ul = DhcpServer.GetUseLdap
      ldap_available = DhcpServer.GetLdapAvailable
      UI.ChangeWidget(Id(id), :Value, ul)
      UI.ChangeWidget(Id(id), :Enabled, ldap_available)

      nil
    end

    # Set the LDAP usage, reinitalize LDAP support
    # @param [Boolean] use_ldap boolean true if LDAP is to be used
    def SetUseLdap(use_ldap)
      DhcpServer.SetUseLdap(use_ldap)
      if !Mode.config
        DhcpServer.InitYapiConfigOptions({ "use_ldap" => use_ldap })
        DhcpServer.LdapInit([], true)
        DhcpServer.CleanYapiConfigOptions
      end

      nil
    end

    # Handle function of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    # @return [Symbol] always nil
    def ldapHandle(id, event)
      event = deep_copy(event)
      ldap = Convert.to_boolean(UI.QueryWidget(Id(id), :Value))
      if ldap != DhcpServer.GetUseLdap
        SetUseLdap(ldap)
        ldap = DhcpServer.GetUseLdap
        UI.ChangeWidget(Id(id), :Value, ldap)
      end
      nil
    end


    # Initialize the widget
    # @param [String] id any widget id
    def OpenFirewallInit(id)
      enabled = SuSEFirewall.GetEnableService
      open = DhcpServer.GetOpenFirewall
      UI.ChangeWidget(Id(id), :Enabled, enabled)
      UI.ChangeWidget(Id(id), :Value, open)

      nil
    end

    # Store settings of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    def OpenFirewallStore(id, event)
      event = deep_copy(event)
      open = Convert.to_boolean(UI.QueryWidget(Id(id), :Value))
      DhcpServer.SetOpenFirewall(open)
      DhcpServer.SetModified

      nil
    end

    def OpenFirewallValidate(id, event)
      event = deep_copy(event)
      open = Convert.to_boolean(UI.QueryWidget(Id(id), :Value))
      enabled = SuSEFirewall.GetEnableService

      if enabled && !open
        # yes-no popup
        if !Popup.YesNo(
            _(
              "The port in firewall is not open. The DHCP server\n" +
                "will not be able to serve your network.\n" +
                "Continue?"
            )
          )
          return false
        end
      end

      # firewall is enabled
      if enabled
        # active interfaces not mentioned in firewall
        ifaces_not_in_fw = []
        Builtins.foreach(@ifaces) do |ifcfg, interface|
          # interface is active
          if Ops.get_boolean(interface, "active", false) == true
            if SuSEFirewall.GetZoneOfInterface(ifcfg) == nil
              ifaces_not_in_fw = Builtins.add(ifaces_not_in_fw, ifcfg)
            end
          end
        end

        # more than one
        if Ops.greater_than(Builtins.size(ifaces_not_in_fw), 1)
          Report.Error(
            Builtins.sformat(
              # TRANSLATORS: popup error message, %1 is list of network interfaces
              _(
                "The network interfaces listed below are not mentioned in any firewall zone.\n" +
                  "%1\n" +
                  "Run the YaST firewall configuration to assign them to a zone."
              ),
              Builtins.mergestring(ifaces_not_in_fw, "\n")
            )
          )
          #return false;
          # FIXME: dialog for adding interfaces into firewall zones
          # only one
        elsif Ops.greater_than(Builtins.size(ifaces_not_in_fw), 0)
          Report.Error(
            Builtins.sformat(
              # TRANSLATORS: popup error message, %1 a network interface name
              _(
                "Network interface %1 is not mentioned in any firewall zone.\nRun the YaST firewall configuration to assign it to a zone."
              ),
              Ops.get(ifaces_not_in_fw, 0, "")
            )
          )
          #return false;
          # FIXME: dialog for adding interfaces into firewall zones
        end
      end

      true
    end

    # Handle function for the advanced options dropdown
    def handle_advanced(_id, event)
      event_id = event["ID"]
      if Mode.config && [:log, :interfaces, :tsig_keys].include?(event_id)
        # popup message
        Popup.Message(
          _(
            "This function is not available during\npreparation for autoinstallation."
          )
        )
        return nil
      end
      if event_id == :log
        LogView.Display(
          {
            "file"    => "/var/log/messages",
            "grep"    => "dhcpd",
            "save"    => true
          }
        )
        return nil
      end
      if [:interfaces, :tsig_keys].include?(event_id)
        event_id
      else
        nil
      end
    end

    # Handle function of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    # @return [Symbol] always nil
    def configTreeHandle(id, event)
      event = deep_copy(event)
      current_item = Convert.to_string(
        UI.QueryWidget(Id("configtree"), :CurrentItem)
      )
      UI.ChangeWidget(Id(:delete), :Enabled, current_item != " ")
      selected = key2typeid(current_item)
      if selected == nil
        Builtins.y2error("Unexistent entry selected")
        return nil
      end
      sel_type = Ops.get(selected, "type", "")
      if ["pool", "class", "host"].include?(sel_type)
        UI.ChangeWidget(Id(:add), :Enabled, false)
      else
        UI.ChangeWidget(Id(:add), :Enabled, true)
      end

      if Ops.get(event, "ID") == "configtree" &&
          Ops.get(event, "EventReason") == "Activated"
        Ops.set(event, "ID", :edit)
      end

      if Ops.get(event, "ID") == :add
        @original_entry_type = ""
        @original_entry_id = ""
        @parent_type = Ops.get(selected, "type", "")
        @parent_id = Ops.get(selected, "id", "")
        @current_entry_options = []
        @current_entry_directives = []
        @current_entry_type = ""
        @current_entry_id = ""
        @current_operation = :add
        return :add
      elsif Ops.get(event, "ID") == :edit
        @current_entry_type = Ops.get(selected, "type", "")
        @current_entry_id = Ops.get(selected, "id", "")
        @current_entry_options = DhcpServer.GetEntryOptions(
          @current_entry_type,
          @current_entry_id
        )
        @current_entry_directives = DhcpServer.GetEntryDirectives(
          @current_entry_type,
          @current_entry_id
        )

        @original_entry_type = @current_entry_type
        @original_entry_id = @current_entry_id
        @parent_type = ""
        @parent_id = ""
        @current_operation = :edit

        return :edit
      elsif Ops.get(event, "ID") == :delete
        DhcpServer.DeleteEntry(
          Ops.get(selected, "type", ""),
          Ops.get(selected, "id", "")
        )
        configTreeInit(id)
      elsif Ops.get(event, "ID") == :move
        return nil
        # TODO move button
      end
      # if (event["ID"]:nil == `add || event["ID"]:nil == `edit)
      #     {
      # 	current_ddns_key_file = DhcpServer::GetDDNSFileName ();
      # 	current_ddns_key_create = DhcpServer::GetDDNSFileCreate ();
      #     }

      nil
    end

    # Initialize the widget
    # @param [String] id any widget id
    def configTreeInit(id)
      items = getItems("", "")
      items = [Item(Id(" "), _("Global Options"), true, items)]
      UI.ReplaceWidget(
        :configtree_rp,
        Tree(
          Id("configtree"),
          Opt(:immediate),
          # tree widget
          _("&Configured Declarations"),
          items
        )
      )
      UI.ChangeWidget(Id("configtree"), :CurrentItem, " ")
      nil
    end

    # Initialize the widget
    # @param [String] id any widget id
    def subnetInit(id)
      l = Builtins.regexptokenize(
        @current_entry_id,
        "^[ \t]*([^ \t]+)[ \t]*netmask[ \t]*([^ \t]+)[ \t]*$"
      )
      UI.ChangeWidget(Id(:subnet), :Value, Ops.get(l, 0, ""))
      UI.ChangeWidget(Id(:netmask), :Value, Ops.get(l, 1, ""))

      nil
    end

    # Store settings of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    def subnetStore(id, event)
      event = deep_copy(event)
      id = Builtins.sformat(
        "%1 netmask %2",
        Convert.to_string(UI.QueryWidget(Id(:subnet), :Value)),
        Convert.to_string(UI.QueryWidget(Id(:netmask), :Value))
      )
      @current_entry_id = id

      nil
    end

    # Initialize the widget
    # @param [String] id any widget id
    def idInit(id)
      UI.ChangeWidget(Id(id), :Value, @current_entry_id)

      nil
    end

    # Store settings of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    def idStore(id, event)
      event = deep_copy(event)
      @current_entry_id = Convert.to_string(UI.QueryWidget(Id(id), :Value))

      nil
    end

    # Initialize the widget
    # @param [String] id string widget id
    def interfacesInit(id)
      allowed_ifaces = DhcpServer.GetAllowedInterfaces
      UI.ChangeWidget(Id(id), :SelectedItems, allowed_ifaces)

      nil
    end

    # Store settings of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    def interfacesStore(id, event)
      event = deep_copy(event)
      selected_ifaces = Convert.to_list(UI.QueryWidget(Id(id), :SelectedItems))
      interfaces = Convert.convert(
        selected_ifaces,
        :from => "list",
        :to   => "list <string>"
      )
      DhcpServer.SetAllowedInterfaces(interfaces)
      DhcpServer.SetModified

      nil
    end

    # Initialize the widget
    # @param [String] id any widget id
    def DynDnsButtonInit(id)
      UI.ReplaceWidget(
        :_tp_table_repl,
        PushButton(
          Id("dyn_dns_button"),
          # push button
          _("&Dynamic DNS")
        )
      )

      nil
    end

    # Handle events of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that is handled
    # @return [Symbol] for WS
    def DynDnsButtonHandle(id, event)
      event = deep_copy(event)
      if Mode.config
        # popup message
        Popup.Message(
          _(
            "This function is not available during\npreparation for autoinstallation."
          )
        )
        return nil
      end
      return :tsig_keys if Builtins.size(DhcpServer.ListTSIGKeys) == 0
      :dyn_dns
    end

    # Handle events of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that is handled
    # @return [Symbol] for WS
    def DDNSZonesHandle(id, event)
      event = deep_copy(event)
      enabled = Convert.to_boolean(UI.QueryWidget(Id("ddns_enable"), :Value))
      UI.ChangeWidget(Id("zone"), :Enabled, enabled)
      UI.ChangeWidget(Id("zone_ip"), :Enabled, enabled)
      UI.ChangeWidget(Id("reverse_zone"), :Enabled, enabled)
      UI.ChangeWidget(Id("reverse_ip"), :Enabled, enabled)
      UI.ChangeWidget(Id("ddns_key"), :Enabled, enabled)
      UI.ChangeWidget(Id("ddns_rev_key"), :Enabled, enabled)
      UI.ChangeWidget(Id(:update_ddns_glob), :Enabled, enabled)
      nil
    end

    # Initialize the widget
    # @param [String] id string widget id
    def DDNSZonesInit(id)
      zone = ""
      ip = ""
      rev_zone = ""
      rev_ip = ""
      key = ""
      rev_key = ""
      UI.ChangeWidget(Id("zone"), :ValidChars, Hostname.ValidCharsDomain)
      UI.ChangeWidget(Id("zone_ip"), :ValidChars, Hostname.ValidCharsDomain)
      UI.ChangeWidget(
        Id("reverse_zone"),
        :ValidChars,
        Hostname.ValidCharsDomain
      )
      UI.ChangeWidget(Id("reverse_ip"), :ValidChars, Hostname.ValidCharsDomain)
      found_ddns = false
      Builtins.foreach(@current_entry_directives) do |d|
        if Ops.get_string(d, "key", "") == "zone"
          value = Ops.get_string(d, "value", "")
          l = Builtins.regexptokenize(
            value,
            "^[ \t]*([^ \t]+)[ \t]*\\{[ \t]*primary[ \t]+([^ \t]+)[ \t]*;[ \t]*key[ \t]+([^ \t]+)[ \t]*;[ \t]*}[ \t]*$"
          )
          if Builtins.size(l) == 3
            z = Ops.get(l, 0, "")
            a = Ops.get(l, 1, "")
            k = Ops.get(l, 2, "")
            if Builtins.issubstring(z, "in-addr.arpa")
              rev_zone = z
              rev_ip = a
              rev_key = k
            else
              zone = z
              ip = a
              key = k
            end
            found_ddns = true
          end
        end
      end

      updater_keys_m = DhcpServer.ListTSIGKeys
      updater_keys = Builtins.maplist(updater_keys_m) do |m|
        Ops.get_string(m, "key", "")
      end

      UI.ReplaceWidget(
        :ddns_key_rp,
        ComboBox(
          Id("ddns_key"),
          # combo box
          _("Forward Zone TSIG &Key"),
          updater_keys
        )
      )
      UI.ReplaceWidget(
        :rev_ddns_key_rp,
        ComboBox(
          Id("ddns_rev_key"),
          # combo box
          _("Reverse Zone TSIG &Key"),
          updater_keys
        )
      )

      if found_ddns
        UI.ChangeWidget(Id("zone"), :Value, zone)
        UI.ChangeWidget(Id("zone_ip"), :Value, ip)
        UI.ChangeWidget(Id("reverse_zone"), :Value, rev_zone)
        UI.ChangeWidget(Id("reverse_ip"), :Value, rev_ip)
        UI.ChangeWidget(Id("ddns_key"), :Value, key)
        UI.ChangeWidget(Id("ddns_rev_key"), :Value, rev_key)
      end
      UI.ChangeWidget(
        Id(:update_ddns_glob),
        :Value,
        DhcpServer.GetAdaptDdnsSettings
      )
      UI.ChangeWidget(Id("ddns_enable"), :Value, found_ddns)
      DDNSZonesHandle(id, {})

      nil
    end

    # Validate the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that is handled
    # @return [Boolean] true if validation succeeded
    def DNSZonesValidate(id, event)
      event = deep_copy(event)
      if !Convert.to_boolean(UI.QueryWidget(Id("ddns_enable"), :Value))
        return true
      end
      ret = true
      Builtins.foreach(["zone", "zone_ip", "reverse_zone", "reverse_ip"]) do |w|
        value = Convert.to_string(UI.QueryWidget(Id(w), :Value))
        if (w == "zone" || w == "reverse_zone") &&
            Builtins.regexpmatch(value, "^.*\\.$")
          value = Builtins.regexpsub(value, "^(.*)\\.$", "\\1")
        end
        if !(Hostname.CheckFQ(value) ||
            Builtins.contains(["zone_ip", "reverse_ip"], w) && IP.Check4(value))
          UI.SetFocus(Id(w))
          Report.Error(Hostname.ValidFQ)
          ret = false
          raise Break
        end
      end
      ret
    end


    # Store settings of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    def DDNSZonesStore(id, event)
      event = deep_copy(event)
      @current_entry_directives = Builtins.filter(@current_entry_directives) do |m|
        Ops.get(m, "key", "") != "zone"
      end
      if Convert.to_boolean(UI.QueryWidget(Id("ddns_enable"), :Value))
        zone = Convert.to_string(UI.QueryWidget(Id("zone"), :Value))
        ip = Convert.to_string(UI.QueryWidget(Id("zone_ip"), :Value))
        rev_zone = Convert.to_string(UI.QueryWidget(Id("reverse_zone"), :Value))
        rev_ip = Convert.to_string(UI.QueryWidget(Id("reverse_ip"), :Value))
        key = Convert.to_string(UI.QueryWidget(Id("ddns_key"), :Value))
        rev_key = Convert.to_string(UI.QueryWidget(Id("ddns_rev_key"), :Value))
        ip = "127.0.0.1" if ip == ""
        rev_ip = "127.0.0.1" if rev_ip == ""
        if zone != ""
          zone = Ops.add(zone, ".") if !Builtins.regexpmatch(zone, "^.*\\.$")
          @current_entry_directives = Builtins.add(
            @current_entry_directives,
            {
              "key"   => "zone",
              "value" => Builtins.sformat(
                "%1 { primary %2; key %3; }",
                zone,
                ip,
                key
              )
            }
          )
        end
        if rev_zone != ""
          if !Builtins.regexpmatch(rev_zone, "^.*\\.$")
            rev_zone = Ops.add(rev_zone, ".")
          end
          @current_entry_directives = Builtins.add(
            @current_entry_directives,
            {
              "key"   => "zone",
              "value" => Builtins.sformat(
                "%1 { primary %2; key %3; }",
                rev_zone,
                rev_ip,
                rev_key
              )
            }
          )
        end
        ug = Convert.to_boolean(UI.QueryWidget(Id(:update_ddns_glob), :Value))
        DhcpServer.SetAdaptDdnsSettings(ug)
      end

      nil
    end

    # Handle events of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that is handled
    # @return [Symbol] for WS
    def KeyFileBrowseButtonHandle(id, event)
      event = deep_copy(event)
      filename = Convert.to_string(UI.QueryWidget(Id("key_filename"), :Value))
      filename = UI.AskForExistingFile(
        filename,
        "",
        # popup headline
        _("Select File with Authentication Key")
      )
      UI.ChangeWidget(Id("key_filename"), :Value, filename) if filename != nil
      nil
    end

    # Validate the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that is handled
    # @return [Boolean] true if validation succeeded
    def EmptyOrIpValidate(id, event)
      event = deep_copy(event)
      val = Convert.to_string(UI.QueryWidget(Id(id), :Value))
      return true if val == "" || IP.Check4(val)
      Popup.Message(IP.Valid4)
      UI.SetFocus(Id(id))
      false
    end



    def optsort(options)
      options = deep_copy(options)
      options = Builtins.toset(options)
      options = Builtins.sort(options)

      o1 = Builtins.filter(options) do |o|
        Builtins.regexpmatch(o, "^option .+$")
      end

      o2 = Builtins.filter(options) do |o|
        !Builtins.regexpmatch(o, "^option .+$")
      end
      Convert.convert(
        Builtins.merge(o2, o1),
        :from => "list",
        :to   => "list <string>"
      )
    end

    def ConfigSummaryInit(key)
      UI.ChangeWidget(
        Id(key),
        :Value,
        Builtins.sformat(
          "<ul><li>%1</li></ul>",
          Builtins.mergestring(DhcpServer.Summary(["no_start"]), "</li>\n<li>")
        )
      )

      nil
    end

    def AllSettingsButtonHandle(key, event)
      event = deep_copy(event)
      :main
    end

    # Handle function for the 'Apply' button
    def handle_apply(_key, event)
      event_id = event["ID"]
      if event_id == "apply"
        SaveAndRestart(event)
      end
      nil
    end

    def init_service_status(_key)
      # If UI::ServiceStatus is used, do not let DnsServer manage the service
      # status, let the user decide
      DhcpServer.SetWriteOnly(true)
      nil
    end

    # Handle function for the ServiceStatus widget
    def handle_service_status(_key, event)
      event_id = event["ID"]
      if @status_widget.handle_input(event_id) == :enabled_changed
        DhcpServer.SetModified if @status_widget.enabled? != DhcpServer.GetStartService
      end
      nil
    end

    # Store settings of the widget
    # @param [String] id string widget id
    # @param [Hash] event map event that caused storing process
    def store_service_status(_key, _event)
      DhcpServer.SetStartService(@status_widget.enabled?)
      nil
    end

    # Initialize widgets
    # Create description map and copy it into appropriate variable of the
    #  DhcpServer module
    def InitWidgets
      options = [
        "option subnet-mask",
        "option broadcast-address",
        "option routers",
        "option static-routes",
        "option domain-name",
        "option domain-name-servers",
        "option host-name",
        "option root-path",
        "option tftp-server-name",
        "option bootfile-name",
        "option dhcp-server-identifier",
        "option time-servers",
        "option ntp-servers",
        "option log-servers",
        "option lpr-servers",
        "option font-servers",
        "option x-display-managers",
        "option smtp-server",
        "option pop-server",
        "option irc-server",
        "option nis-domain",
        "option nis-servers",
        "option nisplus-domain",
        "option nisplus-servers",
        "option interface-mtu",
        "option vendor-encapsulated-options",
        "option vendor-class-identifier",
        "option netbios-name-servers",
        "option netbios-dd-server",
        "option netbios-node-type",
        "option netbios-scope"
      ]

      common_commands = [
        "max-lease-time",
        "default-lease-time",
        "filename",
        "next-server",
        "allow",
        "deny"
      ]

      global_commands = [
        "authoritative",
        "ddns-update-style",
        "ddns-updates",
        "log-facility",
        # FATE #227
        "ldap-dhcp-server-cn"
      ]

      subnet_commands = ["range"]

      host_commands = ["hardware", "fixed-address"]

      class_commands = ["match"]

      shared_net_commands = []

      pool_commands = ["range"]

      group_commands = []

      common_commands = optsort(
        Convert.convert(
          Builtins.merge(common_commands, options),
          :from => "list",
          :to   => "list <string>"
        )
      )
      global_commands = optsort(
        Convert.convert(
          Builtins.merge(global_commands, common_commands),
          :from => "list",
          :to   => "list <string>"
        )
      )
      subnet_commands = optsort(
        Convert.convert(
          Builtins.merge(subnet_commands, common_commands),
          :from => "list",
          :to   => "list <string>"
        )
      )
      host_commands = optsort(
        Convert.convert(
          Builtins.merge(host_commands, common_commands),
          :from => "list",
          :to   => "list <string>"
        )
      )
      shared_net_commands = optsort(
        Convert.convert(
          Builtins.merge(shared_net_commands, common_commands),
          :from => "list",
          :to   => "list <string>"
        )
      )
      pool_commands = optsort(
        Convert.convert(
          Builtins.merge(pool_commands, common_commands),
          :from => "list",
          :to   => "list <string>"
        )
      )
      group_commands = optsort(
        Convert.convert(
          Builtins.merge(group_commands, common_commands),
          :from => "list",
          :to   => "list <string>"
        )
      )

      w = {
        "global_table"         => getOptionsTableWidget(global_commands),
        "host_table"           => getOptionsTableWidget(host_commands),
        "subnet_table"         => getOptionsTableWidget(subnet_commands),
        "shared-network_table" => getOptionsTableWidget(shared_net_commands),
        "pool_table"           => getOptionsTableWidget(pool_commands),
        "group_table"          => getOptionsTableWidget(group_commands),
        "class_table"          => getOptionsTableWidget(class_commands),
        "dyn_dns_button"       => {
          "init"          => fun_ref(method(:DynDnsButtonInit), "void (string)"),
          "handle"        => fun_ref(
            method(:DynDnsButtonHandle),
            "symbol (string, map)"
          ),
          "handle_events" => ["dyn_dns_button"],
          "help"          => Ops.get(@HELPS, "dyn_dns_button", ""),
          "label"         => "&D ",
          #FIXME CWM should be able to handle virtual widgets
          "widget"        => :textentry
        },
        "service_status"         => {
          "widget" => :custom,
          "custom_widget" => @status_widget.widget,
          "help"   => @status_widget.help,
          "init"   => fun_ref(method(:init_service_status), "void (string)"),
          "handle" => fun_ref(method(:handle_service_status), "symbol (string, map)"),
          "store"  => fun_ref(method(:store_service_status), "void (string, map)")
        },
        "apply"           => {
          "widget" => :push_button,
          "label"  => _("Apply Changes"),
          "handle" => fun_ref(method(:handle_apply), "symbol (string, map)"),
          "help"   => ""
        },
        "chroot"               => {
          "widget" => :checkbox,
          # check box
          "label"  => _("&Run DHCP Server in Chroot Jail"),
          "help"   => Ops.get(@HELPS, "chroot", ""),
          "init"   => fun_ref(method(:chrootInit), "void (string)"),
          "handle" => fun_ref(method(:chrootHandle), "symbol (string, map)"),
          "store"  => fun_ref(method(:chrootStore), "void (string, map)")
        },
        "ldap_support"         => {
          "widget" => :checkbox,
          # check box
          "label"  => _("&LDAP Support"),
          "help"   => Ops.get(@HELPS, "ldap_support", " "),
          "init"   => fun_ref(method(:ldapInit), "void (string)"),
          "handle" => fun_ref(method(:ldapHandle), "symbol (string, map)"),
          "opt"    => [:notify]
        },
        "configtree"           => {
          "widget"        => :custom,
          "custom_widget" => VWeight(
            1,
            HBox(
              VWeight(
                1,
                ReplacePoint(
                  Id(:configtree_rp),
                  Tree(
                    Id("configtree"),
                    # tree widget
                    _("&Configured Declarations"),
                    []
                  )
                )
              ),
              VBox(
                PushButton(Id(:add), Label.AddButton),
                PushButton(Id(:edit), Label.EditButton),
                PushButton(Id(:delete), Label.DeleteButton),
              )
            )
          ),
          "help"          => Ops.get(@HELPS, "configtree", ""),
          "init"          => fun_ref(method(:configTreeInit), "void (string)"),
          "handle"        => fun_ref(
            method(:configTreeHandle),
            "symbol (string, map)"
          )
        },
        "advanced"             => {
          "widget"        => :custom,
          "custom_widget" => MenuButton(
            Id(:adv),
            _("Ad&vanced"),
            [
              # item of a menu button
              Item(Id(:log), _("Display &Log")),
              # item of a menu button
              Item(Id(:interfaces), _("&Interface Configuration")),
              # item of a menu button
              Item(Id(:tsig_keys), _("TSIG Key Management"))
            ]
          ),
          "handle"        => fun_ref(method(:handle_advanced), "symbol (string, map)")
        },
        "subnet"               => {
          "widget"        => :custom,
          "custom_widget" => HBox(
            HSpacing(2),
            # text entry
            TextEntry(Id(:subnet), _("&Network Address")),
            # text entry
            TextEntry(Id(:netmask), _("Network &Mask")),
            HSpacing(2)
          ),
          "help"          => Ops.get(@HELPS, "subnet", ""),
          "init"          => fun_ref(method(:subnetInit), "void (string)"),
          "store"         => fun_ref(method(:subnetStore), "void (string, map)")
        },
        "host"                 => {
          "widget" => :textentry,
          # text entry
          "label"  => Label.HostName,
          "help"   => Ops.get(@HELPS, "host", ""),
          "init"   => fun_ref(method(:idInit), "void (string)"),
          "store"  => fun_ref(method(:idStore), "void (string, map)")
        },
        "group"                => {
          "widget" => :textentry,
          # text entry
          "label"  => _("Group &Name"),
          "help"   => Ops.get(@HELPS, "group", ""),
          "init"   => fun_ref(method(:idInit), "void (string)"),
          "store"  => fun_ref(method(:idStore), "void (string, map)")
        },
        "pool"                 => {
          "widget" => :textentry,
          # text entry
          "label"  => _("Pool &Name"),
          "help"   => Ops.get(@HELPS, "pool", ""),
          "init"   => fun_ref(method(:idInit), "void (string)"),
          "store"  => fun_ref(method(:idStore), "void (string, map)")
        },
        "shared-network"       => {
          "widget" => :textentry,
          # text entry
          "label"  => _("Shared Network &Name"),
          "help"   => Ops.get(@HELPS, "shared-network", ""),
          "init"   => fun_ref(method(:idInit), "void (string)"),
          "store"  => fun_ref(method(:idStore), "void (string, map)")
        },
        "class"                => {
          "widget" => :textentry,
          # text entry
          "label"  => _("Class &Name"),
          "help"   => Ops.get(@HELPS, "class", ""),
          "init"   => fun_ref(method(:idInit), "void (string)"),
          "store"  => fun_ref(method(:idStore), "void (string, map)")
        },
        "interfaces"           => {
          "widget"        => :custom,
          "custom_widget" => MultiSelectionBox(
            Id("interfaces"),
            # multi selection box
            _("Available Interfaces"),
            Builtins.maplist(Builtins.filter(SCR.Dir(path(".network.section"))) do |s|
              s != "lo"
            end) { |s| Item(Id(s), s) }
          ),
          "help"          => Ops.get(@HELPS, "interfaces", ""),
          "init"          => fun_ref(method(:interfacesInit), "void (string)"),
          "store"         => fun_ref(
            method(:interfacesStore),
            "void (string, map)"
          )
        },
        "open_firewall"        => {
          "widget"            => :checkbox,
          # check box
          "label"             => _(
            "Open &Firewall for Selected Interfaces"
          ),
          "init"              => fun_ref(
            method(:OpenFirewallInit),
            "void (string)"
          ),
          "store"             => fun_ref(
            method(:OpenFirewallStore),
            "void (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:OpenFirewallValidate),
            "boolean (string, map)"
          ),
          "help"              => Ops.get(@HELPS, "open_firewall", "")
        },
        "ddns_enable"          => {
          "widget"        => :custom,
          "custom_widget" => VBox(
            Left(
              CheckBox(
                Id("ddns_enable"),
                Opt(:notify),
                # check box
                _("&Enable Dynamic DNS for This Subnet")
              )
            ),
            VSpacing(0.5),
            Left(
              ReplacePoint(
                Id(:ddns_key_rp),
                # combo box
                ComboBox(Id("ddns_key"), _("Forward Zone TSIG &Key"))
              )
            ),
            Left(
              ReplacePoint(
                Id(:rev_ddns_key_rp),
                # combo box
                ComboBox(Id("rev_ddns_key"), _("Reverse Zone TSIG &Key"))
              )
            ),
            Left(
              CheckBox(
                Id(:update_ddns_glob),
                # check box
                _("&Update Global Dynamic DNS Settings")
              )
            )
          ),
          # check box
          "help"          => Ops.get(@HELPS, "enable_ddns", "")
        },
        "zone"                 => {
          "widget"            => :textentry,
          # text entry
          "label"             => _("&Zone"),
          "init"              => fun_ref(
            method(:DDNSZonesInit),
            "void (string)"
          ),
          "store"             => fun_ref(
            method(:DDNSZonesStore),
            "void (string, map)"
          ),
          "handle"            => fun_ref(
            method(:DDNSZonesHandle),
            "symbol (string, map)"
          ),
          "handle_events"     => ["ddns_enable"],
          "help"              => Ops.get(@HELPS, "ddns_zones", ""),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:DNSZonesValidate),
            "boolean (string, map)"
          )
        },
        "zone_ip" =>
          #	    "validate_type" : `function,
          #	    "validate_function" : EmptyOrIpValidate,
          {
            "widget" => :textentry,
            # text entry
            "label"  => _("&Primary DNS Server"),
            "help"   => " "
          },
        "reverse_zone"         => {
          "widget" => :textentry,
          # text entry
          "label"  => _("Re&verse Zone"),
          "help"   => " "
        },
        "reverse_ip" =>
          #	    "validate_type" : `function,
          #	    "validate_function" : EmptyOrIpValidate,
          {
            "widget" => :textentry,
            # text entry
            "label"  => _("Pr&imary DNS Server"),
            "help"   => " "
          },
        "tsig_keys"            => CWMTsigKeys.CreateWidget(
          {
            "get_keys_info"  => fun_ref(
              DhcpServer.method(:GetKeysInfo),
              "map <string, any> ()"
            ),
            "set_keys_info"  => fun_ref(
              DhcpServer.method(:SetKeysInfo),
              "void (map <string, any>)"
            ),
            "list_used_keys" => fun_ref(
              DhcpServer.method(:ListUsedKeys),
              "list <string> ()"
            )
          }
        ),
        "config_summary"       => {
          "widget"        => :custom,
          "custom_widget" => RichText(Id("config_summary"), ""),
          "init"          => fun_ref(
            method(:ConfigSummaryInit),
            "void (string)"
          )
        },
        "all_settings_button"  => {
          "widget"        => :push_button,
          # push button
          "label"         => _(
            "DHCP Server &Expert Configuration..."
          ),
          "handle_events" => ["all_settings_button"],
          "handle"        => fun_ref(
            method(:AllSettingsButtonHandle),
            "symbol (string, map)"
          ),
          "help"          => Ops.get(@HELPS, "all_settings_button", "")
        }
      }
      @widgets = deep_copy(w)

      nil
    end
  end
end
