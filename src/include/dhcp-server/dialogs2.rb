# encoding: utf-8

# File:	modules/DhcpServer.ycp
# Package:	Configuration of dhcp-server
# Summary:	Data for configuration of dhcp-server,
#              input and output functions.
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# Representation of the configuration of dhcp-server.
# Input and output routines.
module Yast
  module DhcpServerDialogs2Include
    def initialize_dhcp_server_dialogs2(include_target)
      textdomain "dhcp-server"

      Yast.import "Confirm"
      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "DhcpServer"
      Yast.import "Popup"
      Yast.import "Address"
      Yast.import "IP"
      Yast.import "Hostname"
      Yast.import "Progress"
      Yast.import "DialogTree"
      Yast.import "CWMServiceStart"
      #import "ProductFeatures";
      Yast.import "NetworkInterfaces"
      Yast.import "Report"
      Yast.import "Mode"
      Yast.import "Netmask"

      Yast.include include_target, "dhcp-server/helps.rb"
      Yast.include include_target, "dhcp-server/widgets.rb"
      Yast.include include_target, "dhcp-server/dns-server-management.rb"
      Yast.include include_target, "dhcp-server/dns-server-wizard.rb"

      # Using expert UI
      #define boolean expert_ui = (ProductFeatures::GetFeature ("globals", "ui_mode") == "expert");

      # Start of common configuration section

      @time_combo_items = [
        # combo box item
        Item(Id("days"), _("Days")),
        # combo box item
        Item(Id("hours"), _("Hours")),
        # combo box item
        Item(Id("minutes"), _("Minutes")),
        # combo box item
        Item(Id("seconds"), _("Seconds"))
      ]

      @quit = false

      # Currently selected item in the interface table
      @current_item_iface = nil

      @current_dynamic_dhcp = {}

      @hosts_parent_id = ""

      @hosts = {}

      @valid_opts = {
        "p"    => true,
        "f"    => false,
        "d"    => false,
        "q"    => false,
        "t"    => false,
        "T"    => false,
        "cf"   => true,
        "lf"   => true,
        "tf"   => true,
        "play" => true
      }

      @tabs = {
        "start_up"        => {
          "contents"        => VBox(
            "start_stop",
            VSpacing(),
            "use_ldap",
            VSpacing(),
            HBox("other_options", HStretch()),
            VStretch(),
            Right(
              "apply"
            )
          ),
          # dialog caption
          "caption"         => _("DHCP Server: Start-Up"),
          # dialog caption
          "wizard"          => _("Start-Up"),
          # tree item
          "tree_item_label" => _("Start-Up"),
          "widget_names"    => [
            "start_stop",
            "use_ldap",
            "expert_settings",
            "other_options",
            "apply"
          ]
        },
        "card_selection"  => {
          "contents"        => VBox(
            VSpacing(1),
            Common_CardSelectionDialog(),
            VSpacing(1),
            Left("open_firewall"),
            VStretch()
          ),
          # dialog caption
          "caption"         => _("DHCP Server: Card Selection"),
          # dialog caption
          "wizard"          => _("Card Selection"),
          # tree item
          "tree_item_label" => _("Card Selection"),
          "widget_names"    => [
            "card_selection",
            "open_firewall",
            "expert_settings"
          ]
        },
        "global_settings" => {
          "contents"        => Common_GlobalSettingsDialog(),
          # dialog caption
          "caption"         => _(
            "DHCP Server: Global Settings"
          ),
          # dialog caption
          "wizard"          => _("Global Settings"),
          # tree item
          "tree_item_label" => _("Global Settings"),
          "widget_names"    => ["global_settings", "expert_settings"]
        },
        "dynamic_dhcp"    => {
          "contents"        => Common_DynamicDHCPDialog(),
          # dialog caption
          "caption"         => _("DHCP Server: Dynamic DHCP"),
          # dialog caption
          "wizard"          => _("Dynamic DHCP"),
          # tree item
          "tree_item_label" => _("Dynamic DHCP"),
          "widget_names"    => ["dynamic_dhcp", "expert_settings"]
        },
        "host_management" => {
          "contents"        => Common_HostManagementDialog(),
          # dialog caption
          "caption"         => _(
            "DHCP Server: Host Management"
          ),
          # tree item
          "tree_item_label" => _("Host Management"),
          "widget_names"    => ["host_management", "expert_settings"]
        },
        "expert_settings" => {
          # dialog caption
          "caption"         => _(
            "DHCP Server: Expert Settings"
          ),
          # tree item
          "tree_item_label" => _("Expert Settings"),
          "init"            => fun_ref(
            method(:ExpertSettingsTabInit),
            "symbol (string)"
          )
        },
        "inst_summary"    => {
          "contents"     => VBox(
            VSpacing(1),
            "auto_start_up",
            VSpacing(1),
            "config_summary",
            VSpacing(1),
            "all_settings_button",
            VSpacing(1)
          ),
          # dialog caption
          "wizard"       => _("Start-Up"),
          "widget_names" => [
            "auto_start_up",
            "config_summary",
            "all_settings_button"
          ]
        }
      }

      @new_widgets = Convert.convert(
        Builtins.union(
          @widgets,
          {
            "auto_start_up"   => CWMServiceStart.CreateAutoStartWidget(
              {
                "get_service_auto_start" => fun_ref(
                  method(:GetStartService),
                  "boolean ()"
                ),
                "set_service_auto_start" => fun_ref(
                  method(:SetStartService),
                  "void (boolean)"
                ),
                # radio button
                "start_auto_button"      => _("When &Booting"),
                # radio button
                "start_manual_button"    => _("&Manually"),
                "help"                   => Builtins.sformat(
                  CWMServiceStart.AutoStartHelpTemplate,
                  # part of help text - radio button label, NO SHORTCUT!!!
                  _("When Booting"),
                  # part of help text - radio button label, NO SHORTCUT!!!
                  _("Manually")
                )
              }
            ),
            "use_ldap"        => CWMServiceStart.CreateLdapWidget(
              {
                "get_use_ldap" => fun_ref(
                  DhcpServer.method(:GetUseLdap),
                  "boolean ()"
                ),
                "set_use_ldap" => fun_ref(method(:SetUseLdap), "void (boolean)")
              }
            ),
            "card_selection"  => {
              "widget"            => :custom,
              "custom_widget"     => VBox(),
              "init"              => fun_ref(
                method(:CardSelectionInit),
                "void (string)"
              ),
              "handle"            => fun_ref(
                method(:CardSelectionHandle),
                "symbol (string, map)"
              ),
              "store"             => fun_ref(
                method(:CardSelectionStore),
                "void (string, map)"
              ),
              "validate_type"     => :function,
              "validate_function" => fun_ref(
                method(:CardSelectionValidate),
                "boolean (string, map)"
              ),
              "help"              => Ops.get(
                @HELPS,
                "card_selection_expert",
                ""
              )
            },
            "global_settings" => {
              "widget"            => :custom,
              "custom_widget"     => VBox(),
              "init"              => fun_ref(
                method(:GlobalSettingsInit),
                "void (string)"
              ),
              "handle"            => fun_ref(
                method(:GlobalSettingsHandle),
                "symbol (string, map)"
              ),
              "validate_type"     => :function,
              "validate_function" => fun_ref(
                method(:GlobalSettingsValidate),
                "boolean (string, map)"
              ),
              "store"             => fun_ref(
                method(:GlobalSettingsStore),
                "void (string, map)"
              ),
              "help"              => Ops.add(
                Ops.add(
                  Ops.get(@HELPS, "ldap_support", ""),
                  Ops.get(@HELPS, "ldap_server_name", "")
                ),
                Ops.get(@HELPS, "global_settings", "")
              )
            },
            "dynamic_dhcp"    => {
              "widget"            => :custom,
              "custom_widget"     => VBox(),
              "init"              => fun_ref(
                method(:DynamicDHCPInit),
                "void (string)"
              ),
              "validate_type"     => :function,
              "validate_function" => fun_ref(
                method(:DynamicDHCPValidate),
                "boolean (string, map)"
              ),
              "handle"            => fun_ref(
                method(:DynamicDHCPHandle),
                "symbol (string, map)"
              ),
              "store"             => fun_ref(
                method(:DynamicDHCPStore),
                "void (string, map)"
              ),
              "help"              => Ops.get(@HELPS, "dynamic_dhcp", "")
            },
            "host_management" => {
              "widget"        => :custom,
              "custom_widget" => VBox(),
              "init"          => fun_ref(
                method(:HostManagementInit),
                "void (string)"
              ),
              "handle"        => fun_ref(
                method(:HostManagementHandle),
                "symbol (string, map)"
              ),
              "store"         => fun_ref(
                method(:HostManagementStore),
                "void (string, map)"
              ),
              "help"          => Ops.get(@HELPS, "host_management", "")
            },
            "expert_settings" => {
              "widget"        => :custom,
              "custom_widget" => VBox(),
              "help"          => Ops.get(@HELPS, "expert_settings", " ")
            },
            "config_summary"  => {
              "widget"        => :custom,
              "custom_widget" => Empty(),
              "help"          => Ops.get(@HELPS, "config_summary", " ")
            },
            "other_options"   => {
              "widget"            => :custom,
              "custom_widget"     => TextEntry(
                Id("other_opts"),
                _("DHCP Server Start-up Arguments")
              ),
              "init"              => fun_ref(
                method(:OtherOptionsInit),
                "void (string)"
              ),
              "validate_type"     => :function,
              "validate_function" => fun_ref(
                method(:OtherOptionsValidate),
                "boolean (string, map)"
              ),
              "store"             => fun_ref(
                method(:OtherOptionsStore),
                "void (string, map)"
              ),
              "help"              => Ops.get(@HELPS, "other_options", " ")
            }
          }
        ),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )
    end

    def TimeComboLabelLength
      max_length = 0
      Builtins.foreach(@time_combo_items) do |combo_item|
        combo_label = Ops.get_string(combo_item, 1, " ")
        current_length = Builtins.size(combo_label)
        if Ops.greater_than(current_length, max_length)
          max_length = current_length
        end
      end

      max_length
    end

    def time2seconds(count, unit)
      if unit == "days"
        return Ops.multiply(Ops.multiply(Ops.multiply(count, 60), 60), 24)
      elsif unit == "hours"
        return Ops.multiply(Ops.multiply(count, 60), 60)
      elsif unit == "minutes"
        return Ops.multiply(count, 60)
      end
      count
    end

    def seconds2time(seconds)
      unit = "seconds"
      count = seconds
      if Ops.modulo(seconds, 60 * 60 * 24) == 0
        return {
          "unit"  => "days",
          "count" => Ops.divide(seconds, 60 * 60 * 24)
        }
      end
      if Ops.modulo(seconds, 60 * 60) == 0
        return { "unit" => "hours", "count" => Ops.divide(seconds, 60 * 60) }
      end
      if Ops.modulo(seconds, 60) == 0
        return { "unit" => "minutes", "count" => Ops.divide(seconds, 60) }
      end
      { "unit" => "seconds", "count" => seconds }
    end

    # Common Config Dialog - Card Selection
    # @return [Yast::Term] for Get_CommonDialog()
    def Common_CardSelectionDialog
      dialog = VBox(
        VBox(
          # Table - listing available network cards
          Left(Label(_("Network Cards for DHCP Server"))),
          Table(
            Id("nic_selection"),
            Opt(:notify, :immediate),
            Header(
              # TRANSLATORS: table header item
              _("Selected"),
              # TRANSLATORS: table header item
              _("Interface Name"),
              # TRANSLATORS: table header item
              _("Device Name"),
              # TRANSLATORS: table header item
              _("IP")
            ),
            []
          )
        ),
        HBox(
          # TRANSLATORS: a push-button
          PushButton(Id("add"), _("&Select")),
          # TRANSLATORS: a push-button
          PushButton(Id("remove"), _("&Deselect"))
        ),
        VStretch()
      )

      deep_copy(dialog)
    end

    def SetInterfacesTableButtons
      current_item = Convert.to_string(
        UI.QueryWidget(Id("nic_selection"), :CurrentItem)
      )

      # The currently selected item is active, can be deactivated
      if Ops.get_boolean(@ifaces, [current_item, "active"]) == true
        UI.ChangeWidget(Id("add"), :Enabled, false)
        UI.ChangeWidget(Id("remove"), :Enabled, true) 
        # and vice versa
      else
        UI.ChangeWidget(Id("add"), :Enabled, true)
        UI.ChangeWidget(Id("remove"), :Enabled, false)
      end

      nil
    end

    def RedrawInterfacesTable
      table_items = []
      Builtins.foreach(@ifaces) do |iface, settings|
        table_items = Builtins.add(
          table_items,
          Item(
            Id(iface),
            Ops.get_boolean(settings, "active", false) ? "x" : "",
            iface,
            Ops.get_string(settings, "device", ""),
            Ops.get_string(settings, "ipaddr", "")
          )
        )
      end

      UI.ChangeWidget(Id("nic_selection"), :Items, table_items)
      if @current_item_iface != nil
        UI.ChangeWidget(Id("nic_selection"), :CurrentItem, @current_item_iface)
      end

      SetInterfacesTableButtons()

      nil
    end

    def CardSelectionInit(key)
      Wizard.DisableBackButton

      Builtins.foreach(NetworkInterfaces.List("")) do |iface|
        if iface != "" && !Builtins.issubstring(iface, "lo") &&
            !Builtins.issubstring(iface, "sit")
          device_name = NetworkInterfaces.GetValue(iface, "NAME")
          if Ops.greater_than(Builtins.size(device_name), 40)
            device_name = Ops.add(Builtins.substring(device_name, 0, 37), "...")
          end

          Ops.set(
            @ifaces,
            iface,
            {
              "device" => device_name,
              "ipaddr" => NetworkInterfaces.GetValue(iface, "BOOTPROTO") == "dhcp" ?
                # TRANSLATORS: Table items; Informs that the IP is a DHCP Address
                _("DHCP address") :
                NetworkInterfaces.GetValue(iface, "IPADDR"),
              "active" => false
            }
          )
        end
      end

      dhcp_ifaces = DhcpServer.GetAllowedInterfaces

      Builtins.foreach(@ifaces) do |iface, settings|
        if Builtins.contains(dhcp_ifaces, iface)
          Ops.set(@ifaces, [iface, "active"], true)
        end
      end

      RedrawInterfacesTable()

      nil
    end

    def CardSelectionHandle(key, event)
      event = deep_copy(event)
      item_id = Convert.to_string(
        UI.QueryWidget(Id("nic_selection"), :CurrentItem)
      )

      SetInterfacesTableButtons()

      @current_item_iface = item_id

      if Ops.get(event, "ID") == "add"
        Ops.set(@ifaces, [item_id, "active"], true)
      elsif Ops.get(event, "ID") == "remove"
        Ops.set(@ifaces, [item_id, "active"], false)
      end

      RedrawInterfacesTable()

      nil
    end

    def CardSelectionStore(key, event)
      event = deep_copy(event)
      # FIXME: subnet handling
      allowed_interfaces = []
      Builtins.foreach(@ifaces) do |iface, settings|
        if Ops.get_boolean(@ifaces, [iface, "active"], false) == true
          allowed_interfaces = Builtins.add(allowed_interfaces, iface)
        end
      end

      DhcpServer.SetAllowedInterfaces(allowed_interfaces)
      DhcpServer.SetModified

      nil
    end

    # Checks if selected devices are suitable to run dhcp server
    #
    # A device is valid when:
    # - it has an IP already assigned
    # - it has statically configured IP
    def CardSelectionValidate(key, event)
      return true if event["ID"] == :abort
      return false if !@ifaces

      allowed_interfaces = @ifaces.select { |i, s| s && s["active"] }
      unconfigured_interface = allowed_interfaces.any? do |iface, settings|
        DhcpServer.GetInterfaceInformation(iface).empty?
      end

      if allowed_interfaces.empty?
        # TRANSLATORS: popup error, DHCP Server needs to run on one or more interfaces,
        #              currently no one is selected
        Report.Error(_("At least one network interface must be selected."))
        return false
      end

      if unconfigured_interface
        # TRANSLATORS: popup error, DHCP Server requires selected interface to have
        #              at least minimal configuration
        Report.Error(
          _(
            "One or more selected network interfaces is not configured (no assigned IP address \n" +
              "and netmask)."
          )
        )
        return false
      end
      true
    end

    # Common Config Dialog - Global Settings
    # @return [Yast::Term] for Get_CommonDialog()
    def Common_GlobalSettingsDialog
      ldap = VBox(
        # configuration will be saved in ldap?
        HBox(
          Left(CheckBox(Id("ldap"), Opt(:notify), _("&LDAP Support"), true)),
          HSpacing(2),
          # FATE #227, comments #5 and #17
          Left(
            HSquash(
              TextEntry(
                Id("ldap-dhcp-server-cn"),
                _("DHCP Server &Name (optional)")
              )
            )
          )
        ),
        VSpacing(2)
      )

      dialog = VBox(
        ldap,
        HBox(
          VBox(
            # Textentry with name of the domain
            Left(TextEntry(Id("domainname"), _("&Domain Name"))),
            # Textentry with IP address of primary name server
            Left(TextEntry(Id("primarydnsip"), _("&Primary Name Server IP"))),
            # Textentry with IP address of secondary name server
            Left(
              TextEntry(Id("secondarydnsip"), _("&Secondary Name Server IP"))
            ),
            # Textentry with IP address of default router
            Left(TextEntry(Id("defaultgw"), _("Default &Gateway (Router) ")))
          ),
          HSpacing(2),
          VBox(
            # Textentry with IP address of time server
            Left(TextEntry(Id("timeserver"), _("NTP &Time Server"))),
            # Textentry with IP address of print server
            Left(TextEntry(Id("printserver"), _("&Print Server"))),
            # Textentry with IP address of WINS (Windows Internet Naming Service) server
            Left(TextEntry(Id("winsserver"), _("&WINS Server"))),
            Left(
              HBox(
                # Textentry with default lease time of IP address from dhcp server
                HSquash(
                  TextEntry(Id("defaultleasetime"), _("Default &Lease Time"))
                ),
                HSpacing(0.1),
                MinWidth(
                  TimeComboLabelLength(),
                  # Units for defaultleasetime
                  HSquash(
                    ComboBox(
                      Id("defaultleasetimeunits"),
                      _("&Units"),
                      @time_combo_items
                    )
                  )
                )
              )
            )
          )
        ),
        VStretch()
      )


      deep_copy(dialog)
    end

    def GlobalSettingsValidChars
      # ValidChars definition for GlobalSettingsDialog
      UI.ChangeWidget(Id("domainname"), :ValidChars, Address.ValidChars4)
      UI.ChangeWidget(Id("primarydnsip"), :ValidChars, IP.ValidChars4)
      UI.ChangeWidget(Id("secondarydnsip"), :ValidChars, IP.ValidChars4)
      UI.ChangeWidget(Id("defaultgw"), :ValidChars, Address.ValidChars4)
      UI.ChangeWidget(Id("timeserver"), :ValidChars, Address.ValidChars4)
      UI.ChangeWidget(Id("printserver"), :ValidChars, Address.ValidChars4)
      UI.ChangeWidget(Id("winsserver"), :ValidChars, Address.ValidChars4)
      UI.ChangeWidget(Id("defaultleasetime"), :ValidChars, "0123456789")

      nil
    end

    def CurrentDomainName
      current_domain_name = ""

      Builtins.foreach(DhcpServer.GetEntryOptions("", "")) do |opt|
        if Ops.get(opt, "key") == "domain-name"
          current_domain_name = Ops.get(opt, "value", "")
          if Builtins.regexpmatch(current_domain_name, "^[ \t]*\".*\"[ \t]*$")
            current_domain_name = Builtins.regexpsub(
              current_domain_name,
              "^[ \t]*\"(.*)\"[ \t]*$",
              "\\1"
            )
          end
          raise Break
        end
      end

      current_domain_name
    end

    def GlobalSettingsInit(key)
      # get the global options
      options = DhcpServer.GetEntryOptions("", "")

      options = [] if options == nil

      # setup the corresponding values
      Builtins.foreach(options) do |opt|
        if Ops.get(opt, "key") == "domain-name"
          value2 = Ops.get(opt, "value", "")
          if Builtins.regexpmatch(value2, "^[ \t]*\".*\"[ \t]*$")
            value2 = Builtins.regexpsub(value2, "^[ \t]*\"(.*)\"[ \t]*$", "\\1")
          end
          UI.ChangeWidget(Id("domainname"), :Value, value2)
        elsif Ops.get(opt, "key") == "domain-name-servers"
          vals = Builtins.splitstring(Ops.get(opt, "value", ""), " ,")
          vals = Builtins.filter(vals) { |v| v != "" }
          UI.ChangeWidget(Id("primarydnsip"), :Value, Ops.get(vals, 0, ""))
          UI.ChangeWidget(Id("secondarydnsip"), :Value, Ops.get(vals, 1, ""))
        elsif Ops.get(opt, "key") == "routers"
          vals = Builtins.splitstring(Ops.get(opt, "value", ""), ", ")
          vals = Builtins.filter(vals) { |v| v != "" }
          UI.ChangeWidget(Id("defaultgw"), :Value, Ops.get(vals, 0, ""))
        elsif Ops.get(opt, "key") == "ntp-servers"
          vals = Builtins.splitstring(Ops.get(opt, "value", ""), " ")
          UI.ChangeWidget(Id("timeserver"), :Value, Ops.get(vals, 0, ""))
        elsif Ops.get(opt, "key") == "lpr-servers"
          vals = Builtins.splitstring(Ops.get(opt, "value", ""), " ")
          UI.ChangeWidget(Id("printserver"), :Value, Ops.get(vals, 0, ""))
        elsif Ops.get(opt, "key") == "netbios-name-servers"
          vals = Builtins.splitstring(Ops.get(opt, "value", ""), " ")
          UI.ChangeWidget(Id("winsserver"), :Value, Ops.get(vals, 0, ""))
        end
      end

      # get the global directives
      directives = DhcpServer.GetEntryDirectives("", "")

      directives = [] if directives == nil

      default_lease_time = 14400

      # setup the corresponding values
      Builtins.foreach(directives) do |opt|
        if Ops.get(opt, "key") == "default-lease-time"
          default_lease_time = Builtins.tointeger(Ops.get(opt, "value", "0"))
        end
      end
      vu = seconds2time(default_lease_time)
      value = Ops.get_integer(vu, "count", 0)
      unit = Ops.get_string(vu, "unit", "seconds")
      UI.ChangeWidget(Id("defaultleasetime"), :Value, Builtins.tostring(value))
      UI.ChangeWidget(Id("defaultleasetimeunits"), :Value, unit)

      ldap_in_use = DhcpServer.GetUseLdap
      ldap_available = DhcpServer.GetLdapAvailable

      if ldap_available
        UI.ChangeWidget(Id("ldap"), :Value, ldap_in_use)
        UI.ChangeWidget(
          Id("ldap-dhcp-server-cn"),
          :Value,
          DhcpServer.GetLdapDHCPServerCN
        )
        UI.ChangeWidget(Id("ldap-dhcp-server-cn"), :Enabled, ldap_in_use)
      else
        UI.ChangeWidget(Id("ldap"), :Enabled, ldap_available)
      end

      GlobalSettingsValidChars()

      nil
    end

    def GlobalSettingsHandle(key, event)
      event = deep_copy(event)
      if Ops.get(event, "ID") == "ldap" &&
          Ops.get(event, "EventReason") == "ValueChanged"
        ldap = Convert.to_boolean(UI.QueryWidget(Id("ldap"), :Value))

        # LDAP switch
        SetUseLdap(ldap)
        ldap = DhcpServer.GetUseLdap
        UI.ChangeWidget(Id("ldap"), :Value, ldap)

        # ldap-dhcp-server-cn switch
        UI.ChangeWidget(Id("ldap-dhcp-server-cn"), :Enabled, ldap)
      end
      nil
    end

    def GlobalSettingsStore(key, event)
      event = deep_copy(event)
      directives = []

      # get the global options
      options = DhcpServer.GetEntryOptions("", "")

      directives = [] if directives == nil

      # filter out those we know to change
      keys = [
        "domain-name",
        "domain-name-servers",
        "routers",
        "ntp-servers",
        "lpr-servers",
        "netbios-name-servers"
      ]

      options = Builtins.filter(options) do |opt|
        !Builtins.contains(keys, Ops.get(opt, "key", ""))
      end

      value = Convert.to_string(UI.QueryWidget(Id("domainname"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        options = Builtins.add(
          options,
          {
            "key"   => "domain-name",
            "value" => Builtins.sformat("\"%1\"", value)
          }
        )
      end

      value1 = Convert.to_string(UI.QueryWidget(Id("primarydnsip"), :Value))
      value2 = Convert.to_string(UI.QueryWidget(Id("secondarydnsip"), :Value))
      if Ops.greater_than(Builtins.size(value1), 0) ||
          Ops.greater_than(Builtins.size(value2), 0)
        value1 = value1 == nil ? "" : value1
        value2 = value2 == nil ? "" : value2

        domain_servers = Ops.add(
          value1,
          Ops.greater_than(Builtins.size(value2), 0) ?
            Ops.add(
              Ops.greater_than(Builtins.size(value1), 0) ? ", " : "",
              value2
            ) :
            ""
        )

        options = Builtins.add(
          options,
          { "key" => "domain-name-servers", "value" => domain_servers }
        )
      end

      value = Convert.to_string(UI.QueryWidget(Id("defaultgw"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        options = Builtins.add(
          options,
          { "key" => "routers", "value" => value }
        )
      end

      value = Convert.to_string(UI.QueryWidget(Id("timeserver"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        options = Builtins.add(
          options,
          { "key" => "ntp-servers", "value" => value }
        )
      end

      value = Convert.to_string(UI.QueryWidget(Id("printserver"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        options = Builtins.add(
          options,
          { "key" => "lpr-servers", "value" => value }
        )
      end

      value = Convert.to_string(UI.QueryWidget(Id("winsserver"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        options = Builtins.add(
          options,
          { "key" => "netbios-name-servers", "value" => value }
        )
      end

      DhcpServer.SetEntryOptions("", "", options)

      # get the global directives
      directives = DhcpServer.GetEntryDirectives("", "")
      directives = [] if directives == nil

      # filter out the known ones
      keys = ["default-lease-time"]

      directives = Builtins.filter(directives) do |opt|
        !Builtins.contains(keys, Ops.get(opt, "key", ""))
      end

      value = Convert.to_string(UI.QueryWidget(Id("defaultleasetime"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        val = Builtins.tointeger(value)
        units = Convert.to_string(
          UI.QueryWidget(Id("defaultleasetimeunits"), :Value)
        )
        val = time2seconds(val, units)
        directives = Builtins.add(
          directives,
          { "key" => "default-lease-time", "value" => Builtins.tostring(val) }
        )
      end

      if UI.WidgetExists(Id("ldap-dhcp-server-cn"))
        ldap_dhcp_server_cn = Convert.to_string(
          UI.QueryWidget(Id("ldap-dhcp-server-cn"), :Value)
        )
        DhcpServer.SetLdapDHCPServerCN(ldap_dhcp_server_cn)

        # save ldap-dhcp-server-cn only when set
        if ldap_dhcp_server_cn != ""
          # backslash quotes in the ldap-dhcp-server-cn entry, just to be safe
          ldap_dhcp_server_cn = Builtins.mergestring(
            Builtins.splitstring(ldap_dhcp_server_cn, "\""),
            "\\\""
          )
          directives = Builtins.add(
            directives,
            {
              "key"   => "ldap-dhcp-server-cn",
              "value" => Builtins.sformat("\"%1\"", ldap_dhcp_server_cn)
            }
          )
        end
      end

      DhcpServer.SetEntryDirectives("", "", directives)

      DhcpServer.SetModified

      nil
    end

    def GlobalSettingsValidate(key, event)
      event = deep_copy(event)
      domainname = Convert.to_string(UI.QueryWidget(Id("domainname"), :Value))
      primarydnsip = Convert.to_string(
        UI.QueryWidget(Id("primarydnsip"), :Value)
      )
      secondarydnsip = Convert.to_string(
        UI.QueryWidget(Id("secondarydnsip"), :Value)
      )
      defaultgw = Convert.to_string(UI.QueryWidget(Id("defaultgw"), :Value))
      timeserver = Convert.to_string(UI.QueryWidget(Id("timeserver"), :Value))
      printserver = Convert.to_string(UI.QueryWidget(Id("printserver"), :Value))
      winsserver = Convert.to_string(UI.QueryWidget(Id("winsserver"), :Value))
      defaultleasetime = Convert.to_string(
        UI.QueryWidget(Id("defaultleasetime"), :Value)
      )

      # FIXME:	it is not defined which of values must be filled (must be lease time defined?)
      #		shouldn't be lease time controlled for too small or too big value?

      # checking domain name
      if domainname != "" && Hostname.CheckDomain(domainname) != true
        UI.SetFocus(Id("domainname"))
        Popup.Error(Hostname.ValidDomain)
        return false
      end

      # checking primary server
      if primarydnsip != "" && IP.Check4(primarydnsip) != true
        UI.SetFocus(Id("primarydnsip"))
        Popup.Error(IP.Valid4)
        return false
      end

      # checking secondary server
      if secondarydnsip != "" && IP.Check4(secondarydnsip) != true
        UI.SetFocus(Id("primarydnsip"))
        Popup.Error(IP.Valid4)
        return false
      end

      # checking default gateway server
      if defaultgw != "" && Hostname.Check(defaultgw) != true &&
          Hostname.CheckFQ(defaultgw) != true &&
          IP.Check4(defaultgw) != true
        UI.SetFocus(Id("defaultgw"))
        # error popup
        Popup.Error(
          _("The specified value is not a valid hostname or IP address.")
        )
        return false
      end

      # checking time server
      if timeserver != "" && Hostname.Check(timeserver) != true &&
          Hostname.CheckFQ(timeserver) != true &&
          IP.Check4(timeserver) != true
        UI.SetFocus(Id("timeserver"))
        # error popup
        Popup.Error(
          _("The specified value is not a valid hostname or IP address.")
        )
        return false
      end

      # checking print server
      if printserver != "" && Hostname.Check(printserver) != true &&
          Hostname.CheckFQ(printserver) != true &&
          IP.Check4(printserver) != true
        UI.SetFocus(Id("printserver"))
        # error popup
        Popup.Error(
          _("The specified value is not a valid hostname or IP address.")
        )
        return false
      end

      # checking wins server
      if winsserver != "" && Hostname.Check(winsserver) != true &&
          Hostname.CheckFQ(winsserver) != true &&
          IP.Check4(winsserver) != true
        UI.SetFocus(Id("winsserver"))
        # error popup
        Popup.Error(
          _("The specified value is not a valid hostname or IP address.")
        )
        return false
      end

      true
    end

    # Common Config Dialog - Dynamic DHCP
    # @return [Yast::Term] for Get_CommonDialog()
    def Common_DynamicDHCPDialog
      dialog = VBox(
        # frame
        Frame(
          _("Subnet Information"),
          VBox(
            HBox(
              HWeight(
                2,
                # TRANSLATORS: informative text entry (filled up, disabled)
                TextEntry(Id("current_network"), _("Current &Network"))
              ),
              HWeight(
                2,
                # TRANSLATORS: informative text entry (filled up, disabled)
                TextEntry(Id("current_netmask"), _("Current Net&mask"))
              ),
              HWeight(
                1,
                # TRANSLATORS: informative text entry (filled up, disabled)
                TextEntry(Id("current_bits"), _("Netmask Bi&ts"))
              )
            ),
            HBox(
              HWeight(
                2,
                # text entry
                TextEntry(Id("from_ip_min"), _("Min&imum IP Address"))
              ),
              HWeight(
                2,
                # text entry
                TextEntry(Id("to_ip_max"), _("Ma&ximum IP Address"))
              ),
              HWeight(1, HStretch())
            )
          )
        ),
        VSpacing(1),
        Frame(
          _("IP Address Range"),
          VBox(
            HBox(
              HWeight(
                2,
                # text entry
                TextEntry(Id("from_ip"), _("&First IP Address"))
              ),
              HWeight(
                2,
                # text entry
                TextEntry(Id("to_ip"), _("&Last IP Address"))
              ),
              HWeight(1, HStretch())
            ),
            Left(CheckBox(Id("dyn_bootp"), _("Allow Dynamic &BOOTP")))
          )
        ),
        VSpacing(1),
        Frame(
          # frame label
          _("Lease Time"),
          HBox(
            Opt(:hstretch),
            HWeight(
              # Textentry label - lease time for IPs in the range
              3,
              TextEntry(Id("defaultleasetime"), _("&Default"))
            ),
            HWeight(
              2,
              MinWidth(
                TimeComboLabelLength(),
                # Combobox - type of units for lease time
                ComboBox(
                  Id("defaultleasetimeunits"),
                  _("&Units"),
                  @time_combo_items
                )
              )
            ),
            HSpacing(1),
            HWeight(
              # TextEntryLabel - max. time for leasing of IPs from the range
              3,
              TextEntry(Id("maxleasetime"), _("&Maximum"))
            ),
            HWeight(
              2,
              MinWidth(
                TimeComboLabelLength(),
                # Combobox - type of units for max lease time
                HSquash(
                  ComboBox(
                    Id("maxleasetimeunits"),
                    _("Uni&ts"),
                    @time_combo_items
                  )
                )
              )
            )
          )
        ),
        VStretch(),
        ReplacePoint(Id(:dns_advanced), Empty())
      )

      deep_copy(dialog)
    end

    def DynamicDHCPValidChars
      # ValidChars definition for DynamicDHCPDialog
      UI.ChangeWidget(Id("from_ip"), :ValidChars, IP.ValidChars4)
      UI.ChangeWidget(Id("to_ip"), :ValidChars, IP.ValidChars4)
      UI.ChangeWidget(Id("defaultleasetime"), :ValidChars, "0123456789")
      UI.ChangeWidget(Id("maxleasetime"), :ValidChars, "0123456789")

      nil
    end

    def DynamicDHCPInit(key)
      # find out the our subnet identification

      ifaces_allowed = DhcpServer.GetAllowedInterfaces

      if Ops.greater_than(Builtins.size(ifaces_allowed), 1)
        Builtins.y2warning(
          "More than one interface allowed, using the first one only."
        )
      end

      if Builtins.size(ifaces_allowed) == 0
        Builtins.y2error("No interfaces set")
        return
      end

      interface = Ops.get(ifaces_allowed, 0)
      m = DhcpServer.GetInterfaceInformation(interface)
      id = Ops.add(
        Ops.add(Ops.get_string(m, "network", ""), " netmask "),
        Ops.get_string(m, "netmask", "")
      )
      zone_name = CurrentDomainName()

      @current_dynamic_dhcp = {
        "network" => Ops.get_string(m, "network", ""),
        "netmask" => Ops.get_string(m, "netmask", ""),
        "domain"  => zone_name
      }

      netmask_bits = Netmask.ToBits(
        Ops.get_string(m, "netmask", "255.255.255.255")
      )
      Ops.set(
        @current_dynamic_dhcp,
        "netmask_bits",
        Builtins.tostring(netmask_bits)
      )

      UI.ChangeWidget(
        Id("current_network"),
        :Value,
        Ops.get_string(m, "network", "")
      )
      UI.ChangeWidget(Id("current_network"), :Enabled, false)
      UI.ChangeWidget(
        Id("current_netmask"),
        :Value,
        Ops.get_string(m, "netmask", "")
      )
      UI.ChangeWidget(Id("current_netmask"), :Enabled, false)
      UI.ChangeWidget(
        Id("current_bits"),
        :Value,
        Builtins.tostring(netmask_bits)
      )
      UI.ChangeWidget(Id("current_bits"), :Enabled, false)

      # Computing minimal and maximal IPs
      current_network = IP.ComputeNetwork(
        Ops.get_string(m, "network", ""),
        Ops.get_string(m, "netmask", "255.255.255.255")
      )
      network_binary = IP.IPv4ToBits(current_network)

      Ops.set(@current_dynamic_dhcp, "current_network", current_network)
      Ops.set(@current_dynamic_dhcp, "network_binary", network_binary)

      # generating reverse zone
      if IP.Check(current_network)
        # 10.20.60.2  / 255.255.255.0 -> 60.20.10.in-addr.arpa
        # 135.14.80.2 / 255.255.240.0 -> 14.135.in-addr.arpa
        # 10.20.60.2  / 255.128.0.0   -> 10.in-addr.arpa

        reverse_zone = ""

        # only 255's are valid for a reverse zone
        network_bytes = Ops.divide(netmask_bits, 8)
        network_split = Builtins.splitstring(current_network, ".")
        while Ops.greater_than(network_bytes, 0)
          network_bytes = Ops.subtract(network_bytes, 1)
          reverse_zone = Ops.add(
            Ops.add(reverse_zone, Ops.get(network_split, network_bytes, "")),
            "."
          )
        end
        reverse_zone = Ops.add(reverse_zone, "in-addr.arpa")

        Ops.set(@current_dynamic_dhcp, "reverse_domain", reverse_zone)
      end

      # Computing minimal IP
      ipv4_min = Builtins.regexpsub(network_binary, "^(.*).$", "\\11")
      ipv4_min = IP.BitsToIPv4(ipv4_min)

      # Computing maximal IP
      ipv4_max = Builtins.substring(network_binary, 0, netmask_bits)
      ipv4_max = Ops.add(ipv4_max, "11111111111111111111111111111111")
      ipv4_max = Builtins.substring(ipv4_max, 0, 32)
      # changing the last bit not to be >1< (reserved for broadcast)
      ipv4_max = Builtins.regexpsub(ipv4_max, "(.*)1$", "\\10")
      ipv4_max = IP.BitsToIPv4(ipv4_max)

      Builtins.y2milestone(
        "Network: %1, Min. IP: %2, Max. IP: %3",
        Ops.get_string(m, "network", ""),
        ipv4_min,
        ipv4_max
      )

      UI.ChangeWidget(Id("from_ip_min"), :Enabled, false)
      UI.ChangeWidget(Id("to_ip_max"), :Enabled, false)
      if ipv4_min != nil && ipv4_max != nil
        UI.ChangeWidget(Id("from_ip_min"), :Value, ipv4_min)
        UI.ChangeWidget(Id("to_ip_max"), :Value, ipv4_max)

        Ops.set(@current_dynamic_dhcp, "ipv4_min", ipv4_min)
        Ops.set(@current_dynamic_dhcp, "ipv4_max", ipv4_max)
      end


      Builtins.y2milestone("Id to lookup: %1", id)

      if !DhcpServer.EntryExists("subnet", id)
        DhcpServer.CreateEntry("subnet", id, "", "")
      end


      # FIXME: it may not exist
      directives = DhcpServer.GetEntryDirectives("subnet", id)

      default_lease_time = 14400
      max_lease_time = 172800

      Builtins.foreach(directives) do |opt|
        if Ops.get(opt, "key") == "range"
          range = Builtins.splitstring(Ops.get(opt, "value", ""), " ")
          idx = 0
          if Ops.get(range, 0, "") == "dynamic-bootp"
            UI.ChangeWidget(Id("dyn_bootp"), :Value, true)
            idx = 1
          end
          UI.ChangeWidget(Id("from_ip"), :Value, Ops.get(range, idx, ""))
          UI.ChangeWidget(
            Id("to_ip"),
            :Value,
            Ops.get(range, Ops.add(idx, 1), "")
          )
        elsif Ops.get(opt, "key") == "default-lease-time"
          default_lease_time = Builtins.tointeger(Ops.get(opt, "value", "0"))
        elsif Ops.get(opt, "key") == "max-lease-time"
          max_lease_time = Builtins.tointeger(Ops.get(opt, "value", "0"))
        end
      end if directives != nil
      vu = seconds2time(default_lease_time)
      value = Ops.get_integer(vu, "count", 0)
      unit = Ops.get_string(vu, "unit", "seconds")
      UI.ChangeWidget(Id("defaultleasetime"), :Value, Builtins.tostring(value))
      UI.ChangeWidget(Id("defaultleasetimeunits"), :Value, unit)

      vu = seconds2time(max_lease_time)
      value = Ops.get_integer(vu, "count", 0)
      unit = Ops.get_string(vu, "unit", "seconds")
      UI.ChangeWidget(Id("maxleasetime"), :Value, Builtins.tostring(value))
      UI.ChangeWidget(Id("maxleasetimeunits"), :Value, unit)

      DynamicDHCPValidChars()

      # Synchronize DNS Server -- init
      all_zones = DnsServerAPI.GetZones
      possible_dns_actions = []

      # zone is not maintained by the DNS server
      if Ops.get(all_zones, zone_name) == nil
        possible_dns_actions = [
          Item(
            Id(:dns_advanced_from_scratch),
            _("Create New DNS Zone from Scratch")
          )
        ] 

        # zone is maintained and it is a 'master'
      elsif Ops.get(all_zones, [zone_name, "type"]) == "master"
        possible_dns_actions = [
          Item(
            Id(:dns_advanced_from_scratch),
            _("Create New DNS Zone from Scratch")
          ),
          Item(Id(:dns_advanced_edit_current), _("Edit Current DNS Zone"))
        ] 

        # zone is maintained but it is not a 'master'
      else
        possible_dns_actions = [
          Item(Id(:dns_advanced_zone_info), _("Get Current Zone Information"))
        ]
      end

      UI.ReplaceWidget(
        Id(:dns_advanced),
        MenuButton(
          Id(:dns_advanced_menu),
          _("&Synchronize DNS Server..."),
          possible_dns_actions
        )
      )

      UI.ChangeWidget(
        Id(:dns_advanced_menu),
        :Enabled,
        DhcpServer.IsDnsServerAvailable
      )

      nil
    end

    def DynamicDHCPHandle(key, event)
      event = deep_copy(event)
      return nil if key != "dynamic_dhcp"

      # Only these IDs are handled
      if Ops.get(event, "ID") != :dns_advanced_edit_current &&
          Ops.get(event, "ID") != :dns_advanced_from_scratch &&
          Ops.get(event, "ID") != :dns_advanced_zone_info
        return nil
      end

      # Show DNS Zone Information
      if Ops.get(event, "ID") == :dns_advanced_zone_info
        Report.Message(
          Builtins.sformat(
            _(
              "DNS zone %1 is not a master zone.\nTherefore, you cannot change it here.\n"
            ),
            Ops.get(@current_settings, "domain", "")
          )
        ) 

        # Run the DNS Wizard - Zone from Scratch
      elsif Ops.get(event, "ID") == :dns_advanced_from_scratch
        if !DynamicDHCPValidate(nil, nil)
          Builtins.y2milestone(
            "Dynamic DHCP Validation failed, Not managing DNS Server"
          )
          return nil
        end

        Builtins.y2milestone("Running DNS wizard -- Creating zone from scratch")
        RunNewDNSServerWizard(@current_dynamic_dhcp) 

        # Edit the current DNS Zone - for experts
      elsif Ops.get(event, "ID") == :dns_advanced_edit_current
        if !DynamicDHCPValidate(nil, nil)
          Builtins.y2milestone(
            "Dynamic DHCP Validation failed, Not managing DNS Server"
          )
          return nil
        end

        Builtins.y2milestone("Managing DNS Server")
        ManageDNSServer(@current_dynamic_dhcp)
      end

      nil
    end

    def DynamicDHCPStore(key, event)
      event = deep_copy(event)
      ifaces_allowed = DhcpServer.GetAllowedInterfaces

      # we assume there is only a single interface at this stage
      interface = Ops.get(ifaces_allowed, 0)

      m = DhcpServer.GetInterfaceInformation(interface)
      id = Ops.add(
        Ops.add(Ops.get_string(m, "network", ""), " netmask "),
        Ops.get_string(m, "netmask", "")
      )

      Builtins.y2milestone("Id to store: %1", id)


      directives = DhcpServer.GetEntryDirectives("subnet", id)

      directives = [] if directives == nil

      from_ip = Convert.to_string(UI.QueryWidget(Id("from_ip"), :Value))
      to_ip = Convert.to_string(UI.QueryWidget(Id("to_ip"), :Value))
      dyn_bootp = Convert.to_boolean(UI.QueryWidget(Id("dyn_bootp"), :Value))

      # FIXME: validation

      # now update the directives

      # remove the old ones
      keys = ["max-lease-time", "range", "default-lease-time"]

      directives = Builtins.filter(directives) do |opt|
        !Builtins.contains(keys, Ops.get(opt, "key", ""))
      end

      if Builtins.size(from_ip) != 0 && Builtins.size(to_ip) != 0
        directives = Builtins.add(
          directives,
          {
            "key"   => "range",
            "value" => Ops.add(
              Ops.add(Ops.add(dyn_bootp ? "dynamic-bootp " : "", from_ip), " "),
              to_ip
            )
          }
        )
      end

      value = Convert.to_string(UI.QueryWidget(Id("defaultleasetime"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        val = Builtins.tointeger(value)
        units = Convert.to_string(
          UI.QueryWidget(Id("defaultleasetimeunits"), :Value)
        )
        val = time2seconds(val, units)
        directives = Builtins.add(
          directives,
          { "key" => "default-lease-time", "value" => Builtins.tostring(val) }
        )
      end

      value = Convert.to_string(UI.QueryWidget(Id("maxleasetime"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        val = Builtins.tointeger(value)
        units = Convert.to_string(
          UI.QueryWidget(Id("maxleasetimeunits"), :Value)
        )
        val = time2seconds(val, units)
        directives = Builtins.add(
          directives,
          { "key" => "max-lease-time", "value" => Builtins.tostring(val) }
        )
      end

      DhcpServer.SetEntryDirectives("subnet", id, directives)

      nil
    end
    def DynamicDHCPValidate(key, event)
      event = deep_copy(event)
      from_ip = Convert.to_string(UI.QueryWidget(Id("from_ip"), :Value))
      to_ip = Convert.to_string(UI.QueryWidget(Id("to_ip"), :Value))
      defaultleasetime = Convert.to_string(
        UI.QueryWidget(Id("defaultleasetime"), :Value)
      )
      maxleasetime = Convert.to_string(
        UI.QueryWidget(Id("maxleasetime"), :Value)
      )

      if from_ip == "" && to_ip == ""
        # disable dynamic IP assigning
        return true
      end

      # defined only one, both from and to must be defined
      if from_ip != "" && to_ip == ""
        UI.SetFocus(Id("to_ip"))
        # A popup error text
        Popup.Error(_("Enter values for both ends of the IP address range."))
        return false
      end

      # defined only one, both from and to must be defined
      if from_ip == "" && to_ip != ""
        UI.SetFocus(Id("from_ip"))
        # A popup error text
        Popup.Error(_("Enter values for both ends of the IP address range."))
        return false
      end

      # Checking from_ip for IPv4
      if from_ip != "" && IP.Check4(from_ip) == false
        UI.SetFocus(Id("from_ip"))
        Popup.Error(IP.Valid4)
        return false
      end

      # Checking to_ip for IPv4
      if to_ip != "" && IP.Check4(to_ip) == false
        UI.SetFocus(Id("to_ip"))
        Popup.Error(IP.Valid4)
        return false
      end

      # FIXME: Lease Time should NOT be zero or means zero NO expiration?

      # network of the current network interface
      current_network = IP.ComputeNetwork(
        Ops.get(@current_dynamic_dhcp, "network", ""),
        Ops.get(@current_dynamic_dhcp, "netmask", "")
      )

      # checking from_ip network with the current network
      from_ip_network = IP.ComputeNetwork(
        from_ip,
        Ops.get(@current_dynamic_dhcp, "netmask", "")
      )
      if from_ip_network != "" && current_network != nil &&
          current_network != "" &&
          current_network != from_ip_network
        UI.SetFocus(Id("from_ip"))
        Report.Error(
          # TRANSLATORS: popup error message
          #              %1 is the tested IP which should match network %2 and netmask %3
          Builtins.sformat(
            _(
              "The dynamic DHCP address range must be in the same network as the DHCP server.\nIP %1 does not match the network %2/%3."
            ),
            from_ip,
            Ops.get(@current_dynamic_dhcp, "network", ""),
            Ops.get(@current_dynamic_dhcp, "netmask", "")
          )
        )
        return false
      end

      # checking to_ip network with the current network
      to_ip_network = IP.ComputeNetwork(
        to_ip,
        Ops.get(@current_dynamic_dhcp, "netmask", "")
      )
      if to_ip_network != "" && current_network != nil && current_network != "" &&
          current_network != to_ip_network
        UI.SetFocus(Id("to_ip"))
        Report.Error(
          # TRANSLATORS: popup error message
          #              %1 is the tested IP which should match network %2 and netmask %3
          Builtins.sformat(
            _(
              "The dynamic DHCP address range must be in the same network as the DHCP server.\nIP %1 does not match the network %2/%3."
            ),
            to_ip,
            Ops.get(@current_dynamic_dhcp, "network", ""),
            Ops.get(@current_dynamic_dhcp, "netmask", "")
          )
        )
        return false
      end


      Ops.set(@current_dynamic_dhcp, "from_ip", from_ip)
      Ops.set(@current_dynamic_dhcp, "to_ip", to_ip)

      true
    end

    # Common Config Dialog - Host Management
    # @return [Yast::Term] for Get_CommonDialog()

    def Common_HostManagementDialog
      dialog = VBox(
        VBox(
          # Label of the registered hosts table
          Left(Label(_("Registered Host"))),
          Table(
            Id("registered_hosts_table"),
            Opt(:notify, :immediate, :vstretch),
            Header(
              # Table header item - Name of the host
              _("Name"),
              # Table header item - IP of the host
              _("IP"),
              # MAC address of the host
              _("Hardware Address"),
              # Network type of the host
              _("Type")
            )
          )
        ),
        # Frame label - configuration of particular host
        VSquash(
          Frame(
            _("List Setup"),
            VBox(
              Top(
                HBox(
                  Top(
                    VBox(
                      HBox(
                        # Textentry label - name of the host
                        Left(TextEntry(Id("hostname"), _("&Name"))),
                        # noneditable textentry
                        Left(TextEntry(Id("domain"), Opt(:disabled), "  "))
                      ),
                      # Textentry label - IP address of the host
                      Left(TextEntry(Id("hostip"), _("&IP Address")))
                    )
                  ),
                  HSpacing(2),
                  Top(
                    VBox(
                      # Textentry label - hardware (mac) address of the host
                      Left(
                        TextEntry(Id("hosthwaddress"), _("&Hardware Address"))
                      ),
                      # Radiobutton label - network type of the host
                      RadioButtonGroup(
                        Id("network_type"),
                        HBox(
                          Left(
                            RadioButton(Id("ethernet"), _("&Ethernet"), true)
                          ),
                          Left(RadioButton(Id("token-ring"), _("&Token Ring")))
                        )
                      )
                    )
                  )
                )
              ),
              VSpacing(1),
              Top(
                Left(
                  HBox(
                    # Pushbutton label - add host into list
                    Left(PushButton(Id("addhost"), Label.AddButton)),
                    HSpacing(1),
                    # Pushbutton label - change host in list
                    Left(PushButton(Id("edithost"), _("C&hange in List"))),
                    HSpacing(1),
                    # Pushbutton label - delete host from list
                    Left(PushButton(Id("deletehost"), _("Dele&te from List")))
                  )
                )
              )
            )
          )
        )
      )

      deep_copy(dialog)
    end

    def HostManagementValidChars
      # ValidChars definition for HostManagementDialog
      UI.ChangeWidget(Id("hostname"), :ValidChars, Hostname.ValidChars)
      UI.ChangeWidget(Id("hostip"), :ValidChars, IP.ValidChars4)
      UI.ChangeWidget(
        Id("hosthwaddress"),
        :ValidChars,
        "ABCDEFabcdef0123456789:"
      )

      nil
    end

    def SelectItem(id)
      opts = Ops.get(@hosts, id, {})

      UI.ChangeWidget(Id("hostname"), :Value, id)
      UI.ChangeWidget(Id("hostip"), :Value, Ops.get(opts, "ip", ""))
      UI.ChangeWidget(
        Id("hosthwaddress"),
        :Value,
        Ops.get(opts, "hardware", "")
      )
      UI.ChangeWidget(
        Id("network_type"),
        :CurrentButton,
        Ops.get(opts, "type", "ethernet")
      )

      nil
    end

    def HostManagementInit(key)
      @hosts = {}
      @hosts_parent_id = ""

      ifaces_allowed = DhcpServer.GetAllowedInterfaces

      # we assume there is only a single interface at this stage
      interface = Ops.get(ifaces_allowed, 0)

      m = DhcpServer.GetInterfaceInformation(interface)
      id = Ops.add(
        Ops.add(Ops.get_string(m, "network", ""), " netmask "),
        Ops.get_string(m, "netmask", "")
      )

      @hosts_parent_id = id

      Builtins.y2milestone("Id to get hosts from: %1", id)

      if !DhcpServer.EntryExists("subnet", id)
        DhcpServer.CreateEntry("subnet", id, "", "")
      end

      # now, get the list of interesting children
      children = DhcpServer.GetChildrenOfEntry("subnet", id)

      Builtins.foreach(children) do |child|
        if Ops.get(child, "type") == "host"
          child_id = Ops.get(child, "id", "")
          # let's initialize our cache
          Ops.set(@hosts, child_id, {})

          directives = DhcpServer.GetEntryDirectives(
            "host",
            Ops.get(child, "id", "")
          )
          Builtins.foreach(directives) do |opt|
            if Ops.get(opt, "key") == "hardware"
              parts = Builtins.splitstring(Ops.get(opt, "value", ""), " ")

              Ops.set(@hosts, [child_id, "hardware"], Ops.get(parts, 1, ""))
              Ops.set(@hosts, [child_id, "type"], Ops.get(parts, 0, "ethernet"))
            elsif Ops.get(opt, "key") == "fixed-address"
              Ops.set(@hosts, [child_id, "ip"], Ops.get(opt, "value", ""))
            end
          end
        end
      end

      # now, fill the dialog
      items = Builtins.maplist(@hosts) do |id2, opts|
        Item(
          Id(id2),
          id2,
          Ops.get(opts, "ip", ""),
          Ops.get(opts, "hardware", ""),
          Ops.get(opts, "type", "ethernet") == "ethernet" ?
            _("Ethernet") :
            _("Token Ring")
        )
      end

      UI.ChangeWidget(Id("registered_hosts_table"), :Items, items)

      if Ops.greater_than(Builtins.size(items), 0)
        # fill the corresponding fields
        SelectItem(Ops.get_string(items, [0, 1], ""))
      end

      # get the global options
      options = DhcpServer.GetEntryOptions("", "")

      options = [] if options == nil

      # setup the corresponding values
      Builtins.foreach(options) do |opt|
        if Ops.get(opt, "key") == "domain-name"
          value = Ops.get(opt, "value", "")
          value = Builtins.regexpsub(value, "^[ \t]*\"(.*)\"[ \t]*$", "\\1")
          if Ops.greater_than(Builtins.size(value), 0)
            value = Ops.add(".", value)
          end
          UI.ChangeWidget(Id("domain"), :Value, value)
          raise Break
        end
      end
      HostManagementValidChars()

      nil
    end

    def PrepareDirectives
      directives = []

      value = Convert.to_string(UI.QueryWidget(Id("hostip"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        # FIXME: validation
        directives = Builtins.add(
          directives,
          { "key" => "fixed-address", "value" => value }
        )
      end

      value = Convert.to_string(UI.QueryWidget(Id("hosthwaddress"), :Value))
      if Ops.greater_than(Builtins.size(value), 0)
        # FIXME: validation
        type = Convert.to_string(
          UI.QueryWidget(Id("network_type"), :CurrentButton)
        )
        directives = Builtins.add(
          directives,
          { "key" => "hardware", "value" => Ops.add(Ops.add(type, " "), value) }
        )
      end

      deep_copy(directives)
    end

    def CheckMacAddrFormat
      hosthwaddress = Convert.to_string(
        UI.QueryWidget(Id("hosthwaddress"), :Value)
      )

      addr_type = Convert.to_string(
        UI.QueryWidget(Id("network_type"), :CurrentButton)
      )
      if addr_type == "ethernet" || addr_type == "token-ring"
        if !Address.CheckMAC(hosthwaddress)
          UI.SetFocus(Id("hosthwaddress"))
          Report.Error(
            Ops.add(
              # error popup
              _("The hardware address is invalid.\n"),
              Address.ValidMAC
            )
          )
          return false
        end
      end
      true
    end

    def CheckMacAddrUnique(original)
      existing = DhcpServer.GetChildrenOfEntry("subnet", @hosts_parent_id)
      addresses = Builtins.maplist(existing) do |h|
        if Ops.get(h, "id", "") != original
          directives = DhcpServer.GetEntryDirectives(
            Ops.get(h, "type", ""),
            Ops.get(h, "id", "")
          )
          addr = nil
          Builtins.find(directives) do |d|
            if Ops.get(d, "key", "") == "hardware"
              addr = Ops.get(d, "value", "")
              next true
            end
            false
          end
          next addr
        else
          next nil
        end
      end
      addresses = Builtins.filter(addresses) { |a| a != nil }
      address_unique = true
      Builtins.find(PrepareDirectives()) do |d|
        if Ops.get(d, "key", "") == "hardware"
          if Builtins.contains(addresses, Ops.get(d, "value", ""))
            address_unique = false
          end
          next true
        end
        false
      end

      if !address_unique
        UI.SetFocus(Id("hosthwaddress"))
        # error popup
        Popup.Error(_("The hardware address must be unique."))
        return false
      end
      true
    end

    def CheckHostId(name)
      if Builtins.size(name) == 0
        UI.SetFocus(Id("hostname"))
        # error popup
        Popup.Error(_("The hostname cannot be empty."))
        return false
      elsif !Hostname.Check(name)
        UI.SetFocus(Id("hostname"))
        Popup.Error(Hostname.ValidFQ)
        return false
      elsif Builtins.haskey(@hosts, name)
        UI.SetFocus(Id("hostname"))
        # error popup, %1 is host name
        Popup.Error(
          Builtins.sformat(_("A host named %1 already exists."), name)
        )
        return false
      end
      true
    end

    def HostManagementHandle(key, event_descr)
      event_descr = deep_copy(event_descr)
      if Ops.get_string(event_descr, "ID", "") == "addhost"
        name = Convert.to_string(UI.QueryWidget(Id("hostname"), :Value))
        return nil if !CheckHostId(name)

        # checking new IP
        hostip = Convert.to_string(UI.QueryWidget(Id("hostip"), :Value))
        if Builtins.size(hostip) == 0
          UI.SetFocus(Id("hostip"))
          # error popup
          Popup.Error(_("Enter a host IP."))
          return nil
        elsif IP.Check4(hostip) != true
          UI.SetFocus(Id("hostip"))
          Popup.Error(IP.Valid4)
          return nil
        end

        # checking new MAC
        hosthwaddress = Convert.to_string(
          UI.QueryWidget(Id("hosthwaddress"), :Value)
        )
        if Builtins.size(hosthwaddress) == 0
          UI.SetFocus(Id("hosthwaddress"))
          # error popup
          Report.Error(_("The hardware address must be defined."))
          return nil
        end
        # check the syntax
        return nil if !CheckMacAddrFormat()

        # check if MAC address is unique
        return nil if !CheckMacAddrUnique(nil)

        # finally create the entry
        DhcpServer.CreateEntry("host", name, "subnet", @hosts_parent_id)
        DhcpServer.SetEntryDirectives("host", name, PrepareDirectives())

        HostManagementInit(key)
      elsif Ops.get_string(event_descr, "ID", "") == "deletehost"
        id = Convert.to_string(
          UI.QueryWidget(Id("registered_hosts_table"), :CurrentItem)
        )

        if id == nil
          # error popup
          Popup.Error(_("Select a host first."))
          return nil
        end
        # yes-no popup
        return nil if !Confirm.Delete(id)

        DhcpServer.DeleteEntry("host", id)

        HostManagementInit(key)
      elsif Ops.get_string(event_descr, "ID", "") == "edithost"
        id = Convert.to_string(
          UI.QueryWidget(Id("registered_hosts_table"), :CurrentItem)
        )

        if id == nil
          Popup.Error(_("Select a host first."))
          return nil
        end

        # check the new ID
        new_id = Convert.to_string(UI.QueryWidget(Id("hostname"), :Value))
        return nil if new_id != id && !CheckHostId(new_id)

        # checking new IP
        hostip = Convert.to_string(UI.QueryWidget(Id("hostip"), :Value))
        if Builtins.size(hostip) == 0
          # FIXME: text?
          UI.SetFocus(Id("hostip"))
          Popup.Error(_("Enter a host IP."))
          return nil
        elsif IP.Check4(hostip) != true
          UI.SetFocus(Id("hostip"))
          Popup.Error(IP.Valid4)
          return nil
        end

        # checking new MAC
        hosthwaddress = Convert.to_string(
          UI.QueryWidget(Id("hosthwaddress"), :Value)
        )
        if Builtins.size(hosthwaddress) == 0
          UI.SetFocus(Id("hosthwaddress"))
          Popup.Error(_("The input value must be defined."))
          return nil
        end

        # check the syntax
        return nil if !CheckMacAddrFormat()

        # check if MAC address is unique
        return nil if !CheckMacAddrUnique(id)

        if id != new_id
          DhcpServer.DeleteEntry("host", id)
          id = new_id
          DhcpServer.CreateEntry("host", id, "subnet", @hosts_parent_id)
        end
        DhcpServer.SetEntryDirectives("host", id, PrepareDirectives())

        HostManagementInit(key)
      elsif Ops.get_string(event_descr, "ID", "") == "registered_hosts_table" &&
          Ops.get_string(event_descr, "EventReason", "") == "SelectionChanged"
        id = Convert.to_string(
          UI.QueryWidget(Id("registered_hosts_table"), :CurrentItem)
        )

        SelectItem(id) if id != nil
      end
      nil
    end

    def HostManagementStore(key, event)
      event = deep_copy(event)
      nil
    end

    def ExpertSettingsTabInit(tab)
      Builtins.y2warning("Tab: %1", tab)
      if tab == "expert_settings"
        # yes-no popup
        if !Popup.YesNo(
            _(
              "If you enter the expert settings, you cannot return \n" +
                "to this dialog. You may be able to display this dialog \n" +
                "by saving the changes and restarting the module. \n" +
                "If too complex a configuration is set, the expert \n" +
                "settings dialog is displayed when you\n" +
                "start the DHCP server module.\n" +
                "\n" +
                "Continue?"
            )
          )
          return :refuse_display
        else
          return :expert
        end
      end
      nil
    end

    def OtherOptionsInit(key)
      params = DhcpServer.GetOtherOptions
      UI.ChangeWidget(Id("other_opts"), :Value, params)

      nil
    end

    def OtherOptionsValidate(key, event)
      event = deep_copy(event)
      cmdline = Convert.to_string(UI.QueryWidget(Id("other_opts"), :Value))
      #remove leading '-'
      if Ops.greater_than(Builtins.size(cmdline), 0)
        cmdline = Builtins.substring(cmdline, 1)
      end
      correct = true

      options = Builtins.listmap(Builtins.splitstring(cmdline, "-")) do |s|
        wrk = Builtins.splitstring(s, " ")
        { Ops.get(wrk, 0, "") => Ops.get(wrk, 1, "") }
      end

      Builtins.y2milestone("Cmdline options: %1", options)

      Builtins.foreach(options) do |k, v|
        if !Builtins.haskey(@valid_opts, k)
          UI.SetFocus(Id("other_opts"))
          Popup.Error(
            Builtins.sformat(
              _("\"-%1\" is not a valid DHCP server commandline option"),
              k
            )
          )
          correct = false
          raise Break
        else
          if v == "" && Ops.get(@valid_opts, k, false)
            UI.SetFocus(Id("other_opts"))
            Popup.Error(
              Builtins.sformat(
                _("DHCP server commandline option \"-%1\" requires an argument"),
                k
              )
            )
            correct = false
            raise Break
          end
          if k == "cf"
            UI.SetFocus(Id("other_opts"))
            correct = Popup.ContinueCancel(
              Builtins.sformat(
                _(
                  "You have specified an alternate configuration file for the DHCP server.\n" +
                    "\n" +
                    "YaST does not supported this. The DHCP server module can only read and write\n" +
                    "/etc/dhcpd.conf. The new configuration from %1 will not be imported. All\n" +
                    "changes will be saved to the default configuration file.\n" +
                    " \n" +
                    "Really continue?\n"
                ),
                v
              )
            )
            raise Break
          end
        end
      end
      #    y2milestone("Commandline options parsed");
      correct
    end

    def OtherOptionsStore(key, event)
      event = deep_copy(event)
      params = Convert.to_string(UI.QueryWidget(Id("other_opts"), :Value))

      DhcpServer.SetOtherOptions(params)

      nil
    end

    def GetStartService
      DhcpServer.GetStartService
    end

    def SetStartService(start)
      DhcpServer.SetStartService(start)

      nil
    end

    # Common Config Dialog
    # @return [Symbol] for the wizard sequencer
    def CommonConfigDialog
      ids_order = [
        "start_up",
        "card_selection",
        "global_settings",
        "dynamic_dhcp",
        "host_management",
        "expert_settings"
      ]
      DialogTree.ShowAndRun(
        {
          "ids_order"      => ids_order,
          "initial_screen" => "start_up",
          "screens"        => @tabs,
          "widget_descr"   => @widgets,
          "back_button"    => "",
          "abort_button"   => Label.CancelButton,
          "next_button"    => Label.OKButton,
          "functions"      => @functions
        }
      )
    end



    def FirstRunDialog(current_tab, step_number)
      tab_descr = Ops.get(@tabs, current_tab, {})

      # dialog caption, %1 is step number
      caption = Ops.add(
        Ops.add(
          Builtins.sformat(_("DHCP Server Wizard (%1 of 4)"), step_number),
          ": "
        ),
        Ops.get_string(tab_descr, "wizard", "")
      )

      ret = CWM.ShowAndRun(
        {
          "widget_names"       => Ops.get_list(tab_descr, "widget_names", []),
          "widget_descr"       => @widgets,
          "contents"           => Ops.get_term(tab_descr, "contents", VBox()),
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "next_button"        => step_number == 4 ?
            Label.FinishButton :
            Label.NextButton,
          "fallback_functions" => {
            :abort => fun_ref(method(:confirmAbortIfChanged), "boolean ()")
          }
        }
      )

      ret
    end
  end
end
