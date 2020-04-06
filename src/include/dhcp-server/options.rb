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
  module DhcpServerOptionsInclude
    def initialize_dhcp_server_options(include_target)
      textdomain "dhcp-server"

      Yast.import "Address"
      Yast.import "DhcpServer"
      Yast.import "IP"
      Yast.import "Label"

      @option_types = {
        "option all-subnets-local"                      => "onoff",
        "option arp-cache-timeout"                      => "uint32",
        "option bootfile-name"                          => "text",
        "option boot-size"                              => "uint16",
        "option broadcast-address"                      => "ip-address",
        "option cookie-servers"                         => "array_ip-address",
        "option default-ip-ttl"                         => "uint8",
        "option default-tcp-ttl"                        => "uint8",
        "option dhcp-client-identifier"                 => "string",
        "option dhcp-max-message-size"                  => "uint16",
        "option domain-name"                            => "text",
        "option domain-name-servers"                    => "array_ip-address",
        "option extensions-path"                        => "text",
        "option finger-server"                          => "array_ip-address",
        "option font-servers"                           => "array_ip-address",
        "option host-name"                              => "quoted_string",
        "option ieee802-3-encapsulation"                => "onoff",
        "option ien116-name-servers"                    => "array_ip-address",
        "option impress-servers"                        => "array_ip-address",
        "option interface-mtu"                          => "uint16",
        "option ip-forwarding"                          => "onoff",
        "option irc-server"                             => "array_ip-address",
        "option log-servers"                            => "array_ip-address",
        "option lpr-servers"                            => "array_ip-address",
        "option mask-supplier"                          => "onoff",
        "option max-dgram-reassembly"                   => "uint16",
        "option merit-dump"                             => "text",
        "option mobile-ip-home-agent"                   => "array_ip-address",
        "option nds-context"                            => "string",
        "option nds-servers"                            => "array_ip-address",
        "option nds-tree-name"                          => "string",
        "option netbios-dd-server"                      => "array_ip-address",
        "option netbios-name-servers"                   => "array_ip-address",
        "option netbios-node-type"                      => "uint8",
        "option netbios-scope"                          => "string",
        "option nis-domain"                             => "text",
        "option nis-servers"                            => "array_ip-address",
        "option nisplus-domain"                         => "text",
        "option nisplus-servers"                        => "array_ip-address",
        "option nntp-server"                            => "array_ip-address",
        "option non-local-source-routing"               => "onoff",
        "option ntp-servers"                            => "array_ip-address",
        "option nwip-domain"                            => "string",
        "option nwip-suboptions"                        => "string",
        "option path-mtu-aging-timeout"                 => "uint32",
        "option path-mtu-plateau-table"                 => "array_uint16",
        "option perform-mask-discovery"                 => "onoff",
        "option policy-filter"                          => "array_ip-address_pair",
        "option pop-server"                             => "array_ip-address",
        "option resource-location-servers"              => "array_ip-address",
        "option root-path"                              => "text",
        "option router-discovery"                       => "onoff",
        "option router-solicitation-address"            => "ip-address",
        "option routers"                                => "array_ip-address",
        "option slp-directory-agent"                    => "slp-discovery-agent",
        "option slp-service-scope"                      => "slp-service-scope",
        "option smtp-server"                            => "array_ip-address",
        "option static-routes"                          => "array_ip-address_pair",
        "option streettalk-directory-assistance-server" => "array_ip-address",
        "option streettalk-server"                      => "array_ip-address",
        "option subnet-mask"                            => "ip-address",
        "option swap-server"                            => "ip-address",
        "option tcp-keepalive-garbage"                  => "onoff",
        "option tcp-keepalive-interval"                 => "uint32",
        "option tftp-server-name"                       => "text",
        "option time-offset"                            => "int32",
        "option time-servers"                           => "array_ip-address",
        "option trailer-encapsulation"                  => "onoff",
        "option uap-servers"                            => "text",
        "option www-server"                             => "array_ip-address",
        "option x-display-manager"                      => "array_ip-address",
        "option fqdn.no-client-update"                  => "onoff",
        "option fqdn.server-update"                     => "onoff",
        "option fqdn.encoded"                           => "onoff",
        "option fqdn.rcode1"                            => "onoff",
        "option fqdn.rcode2"                            => "onoff",
        "option fqdn.fqdn"                              => "text",
        "option nwip.nsq-broadcast"                     => "onoff",
        "option nwip.preferred-dss"                     => "array_ip-address",
        "option nwip.nearest-nwip-server"               => "array_ip-address",
        "option nwip.autoretries"                       => "uint8",
        "option nwip.autoretry-secs"                    => "uint8",
        "option nwip.nwip-1-1"                          => "uint8",
        "option nwip.primary-dss"                       => "ip-address",
        "option vendor-class-identifier"                => "quoted_string",
        "allow"                                         => "adi",
        "deny"                                          => "adi",
        "ignore"                                        => "adi",
        "ldap-dhcp-server-cn"                           => "text",
        # Possible values in the scope:
        # unknown-clients
        # known-clients
        # bootp
        # booting
        # duplicates
        # declines
        # client-updates
        # known-clients
        # unknown-clients
        # members of &quot;class&quot;
        # dynamic bootp clients
        # authenticated clients
        # unauthenticated clients
        # all clients
        #
        # authenticated clients
        # unauthenticated clients
        # all clients
        "always-broadcast"                              => "onoff",
        "always-reply-rfc1048"                          => "onoff",
        "authoritative"                                 => "flag",
        "not authoritative"                             => "flag",
        "boot-unknown-clients"                          => "onoff",
        "ddns-hostname"                                 => "name",
        "ddns-domainname"                               => "name",
        "ddns-rev-domainname"                           => "name",
        "ddns-update-style"                             => "style",
        "ddns-updates"                                  => "onoff",
        "default-lease-time"                            => "time",
        "do-forward-updates"                            => "onoff",
        "dynamic-bootp-lease-cutoff"                    => "date",
        "dynamic-bootp-lease-length"                    => "length",
        "filename"                                      => "text",
        "fixed-address"                                 => "ip-address",
        "get-lease-hostnames"                           => "onoff",
        "hardware"                                      => "hardware",
        "lease-file-name"                               => "name",
        "local-port"                                    => "port",
        "log-facility"                                  => "facility",
        "max-lease-time"                                => "time",
        "min-lease-time"                                => "time",
        "min-secs"                                      => "seconds",
        "next-server"                                   => "server-name",
        "omapi-port"                                    => "port",
        "one-lease-per-client"                          => "onoff",
        "pid-file-name"                                 => "name",
        "ping-check"                                    => "onoff",
        "ping-timeout"                                  => "seconds",
        "server-identifier"                             => "hostname",
        "server-name"                                   => "name",
        "site-option-space"                             => "name",
        "stash-agent-options"                           => "onoff",
        "update-optimization"                           => "onoff",
        "update-static-leases"                          => "onoff",
        "use-host-decl-names"                           => "onoff",
        "use-lease-addr-for-default-route"              => "onoff",
        "vendor-option-space"                           => "string"
      }

      @widget_types = {
        "uint8"                 => uint8_widget,
        "uint16"                => uint16_widget,
        "uint32"                => uint32_widget,
        "int32"                 => int32_widget,
        "text"                  => text_widget,
        "quoted_string"         => quoted_string_widget,
        "string"                => { "_fill" => "" }, # just to make the map non-empty
        "time"                  => { "_fill" => "" }, # just to make the map non-empty
        "ip-address"            => ip_address_widget,
        "array_ip-address"      => array_ip_address_widget,
        "array_uint16"          => array_uint16_widget,
        "array_ip-address_pair" => array_ip_address_pair_widget
      }
    end

    # generic routines

    # Fetch value from structures
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @return [Object] the value
    def fetchValue(opt_id, key)
      opt_id = deep_copy(opt_id)
      return nil if opt_id == nil
      index = Builtins.tointeger(
        Builtins.regexpsub(
          Convert.to_string(opt_id),
          "^[a-z]+ ([0-9]+)$",
          "\\1"
        )
      )
      value = ""
      if Builtins.substring(key, 0, 7) == "option "
        value = Ops.get(@current_entry_options, [index, "value"], "")
      else
        value = Ops.get(@current_entry_directives, [index, "value"], "")
      end
      value
    end

    # Store value to structures
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @param [Object] value any value to store
    def storeValue(opt_id, key, value)
      opt_id = deep_copy(opt_id)
      value = deep_copy(value)
      if opt_id == nil
        if Builtins.substring(key, 0, 7) == "option "
          @current_entry_options = Builtins.add(
            @current_entry_options,
            { "key" => Builtins.substring(key, 7), "value" => value }
          )
        else
          @current_entry_directives = Builtins.add(
            @current_entry_directives,
            { "key" => key, "value" => value }
          )
        end
        return
      end
      return if !Ops.is_string?(opt_id)
      index = Builtins.tointeger(
        Builtins.regexpsub(
          Convert.to_string(opt_id),
          "^[a-z]+ ([0-9]+)$",
          "\\1"
        )
      )
      if Builtins.substring(key, 0, 7) == "option "
        Ops.set(
          @current_entry_options,
          [index, "value"],
          Convert.to_string(value)
        )
      else
        Ops.set(
          @current_entry_directives,
          [index, "value"],
          Convert.to_string(value)
        )
      end

      nil
    end

    # Fallback function to initialize the settings in the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def commonPopupInit(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = fetchValue(opt_id, key)
      UI.ChangeWidget(Id(key), :Value, value) if value != nil
      UI.SetFocus(Id(key))

      nil
    end

    # Fallback function to save settings from the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def commonPopupSave(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = UI.QueryWidget(Id(key), :Value)
      storeValue(opt_id, key, value)

      nil
    end

    # Fallback function to display summary text in the table
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @return [String] summary to be written to the table
    def commonTableEntrySummary(opt_id, key)
      opt_id = deep_copy(opt_id)
      return "" if !Ops.is_string?(opt_id)
      index = Builtins.tointeger(
        Builtins.regexpsub(
          Convert.to_string(opt_id),
          "^[a-z]+ ([0-9]+)$",
          "\\1"
        )
      )
      if Builtins.substring(key, 0, 7) == "option "
        return Builtins.sformat(
          "%1",
          Ops.get(@current_entry_options, [index, "value"], "")
        )
      else
        return Builtins.sformat(
          "%1",
          Ops.get(@current_entry_directives, [index, "value"], "")
        )
      end
    end

    # Initialize the settings in the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def textWidgetInit(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = Convert.to_string(fetchValue(opt_id, key))
      if value != nil
        while value != "" && Builtins.substring(value, 0, 1) == "\""
          value = Builtins.substring(value, 1)
        end
        while value != "" &&
            Builtins.substring(value, Ops.subtract(Builtins.size(value), 1)) == "\""
          value = Builtins.substring(
            value,
            0,
            Ops.subtract(Builtins.size(value), 1)
          )
        end
        UI.ChangeWidget(Id(key), :Value, value)
      end
      UI.SetFocus(Id(key))

      nil
    end

    # Initialize the settings in the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def quoted_string_init(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = Convert.to_string(fetchValue(opt_id, key))
      if value != nil
        # removing quotes around
        if Builtins.regexpmatch(value, "^\".*\"$")
          value = Builtins.regexpsub(value, "\"(.*)\"", "\\1")

          # if it was quoted, replacing all >\"< with >"<
          while Builtins.regexpmatch(value, ".*\\\\\".*")
            value = Builtins.regexpsub(value, "(.*)\\\\\"(.*)", "\\1\"\\2")
          end
        end
        UI.ChangeWidget(Id(key), :Value, value)
      end
      UI.SetFocus(Id(key))

      nil
    end

    # Summary function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    def textWidgetStore(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = UI.QueryWidget(Id(key), :Value)
      value = Builtins.sformat("\"%1\"", value)
      storeValue(opt_id, key, value)

      nil
    end

    # Validate function of a popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    # @param [Hash] event map representing the event that caused validation
    # @return [Boolean] true if widget settings ok
    def ip_address_validate(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      value = Convert.to_string(UI.QueryWidget(Id(key), :Value))
      if !Address.Check4(value)
        Popup.Message(IP.Valid4)
        UI.SetFocus(Id(key))
        return false
      end
      true
    end


    # Redraw selection box widget
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    # @param [Hash] event map event that caused the operation
    # @param [String] label string label of the selection box
    def redraw_list(opt_id, key, event, label)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      if Ops.get(event, "ID") == :delete
        del_addr = Convert.to_string(
          UI.QueryWidget(Id(:addresses), :CurrentItem)
        )
        @entry_list = Builtins.filter(@entry_list) { |a| a != del_addr }
      end
      UI.ReplaceWidget(
        :addresses_rp,
        SelectionBox(Id(:addresses), label, @entry_list)
      )
      UI.ChangeWidget(
        Id(:delete),
        :Enabled,
        Ops.greater_than(Builtins.size(@entry_list), 0)
      )
      if Ops.greater_than(Builtins.size(@entry_list), 0)
        UI.ChangeWidget(
          Id(:addresses),
          :CurrentItem,
          Ops.get(@entry_list, 0, "")
        )
      end

      nil
    end

    # Initialize a selection box
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @param [String] label string label of the selection box
    def init_list(opt_id, key, label)
      opt_id = deep_copy(opt_id)
      value = Convert.to_string(fetchValue(opt_id, key))
      value = "" if value == nil
      values = Builtins.splitstring(value, ",")
      values = Builtins.maplist(values) do |v|
        while v != "" && Builtins.substring(v, 0, 1) == " "
          v = Builtins.substring(v, 1)
        end
        while v != "" &&
            Builtins.substring(v, Ops.subtract(Builtins.size(v), 1), 1) == " "
          v = Builtins.substring(v, 0, Ops.subtract(Builtins.size(v), 1))
        end
        v
      end
      @entry_list = Builtins.filter(values) { |v| v != "" }
      redraw_list(opt_id, key, {}, label)

      nil
    end

    # Initialize the settings in the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def ip_array_init(opt_id, key)
      opt_id = deep_copy(opt_id)
      # selection box
      init_list(opt_id, key, _("A&ddresses"))

      nil
    end

    # Handle the event on the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @param [Hash] event map event to be handled
    def ip_array_handle(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      if Ops.get(event, "ID") == :add
        new_addr = Convert.to_string(UI.QueryWidget(Id(:new_addr), :Value))
        if !Address.Check(new_addr)
          # popup message
          Popup.Message(_("The entered address is not valid."))
          return nil
        end
        @entry_list = Builtins.add(@entry_list, new_addr)
      end
      redraw_list(opt_id, key, event, _("A&ddresses"))

      nil
    end

    # Validate function of a popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    # @param [Hash] event map representing the event that caused validation
    # @return [Boolean] true if widget settings ok
    def ip_array_validate(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      if Builtins.size(@entry_list) == 0
        # message popup
        Popup.Message(_("At least one address must be specified."))
        return false
      end
      true
    end

    # Store function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    def entry_array_store(opt_id, key)
      opt_id = deep_copy(opt_id)
      storeValue(opt_id, key, Builtins.mergestring(@entry_list, ", "))

      nil
    end

    # Initialize the settings in the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def uint16_array_init(opt_id, key)
      opt_id = deep_copy(opt_id)
      # selection box
      init_list(opt_id, key, _("&Values"))

      nil
    end

    # Handle the event on the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @param [Hash] event map event to be handled
    def uint16_array_handle(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      if Ops.get(event, "ID") == :add
        val = Convert.to_integer(UI.QueryWidget(Id(:new_addr), :Value))
        @entry_list = Builtins.add(@entry_list, Builtins.tostring(val))
      end
      redraw_list(opt_id, key, event, _("&Values"))

      nil
    end

    # Validate function of a popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    # @param [Hash] event map representing the event that caused validation
    # @return [Boolean] true if widget settings ok
    def value_array_validate(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      if Builtins.size(@entry_list) == 0
        # message popup
        Popup.Message(_("At least one address must be specified."))
        return false
      end
      true
    end

    # Handle the event on the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @param [Hash] event map event to be handled
    def ip_pair_array_handle(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      if Ops.get(event, "ID") == :add
        new_addr = Convert.to_string(UI.QueryWidget(Id(:new_addr), :Value))
        l = Builtins.splitstring(new_addr, " ")
        l = Builtins.filter(l) { |s| s != "" }
        if !(Builtins.size(l) == 2 && Address.Check(Ops.get(l, 0, "")) &&
            Address.Check(Ops.get(l, 1, "")))
          # message popup
          Popup.Message(_("The entered addresses are not valid."))
          return nil
        end
        @entry_list = Builtins.add(@entry_list, new_addr)
      end
      redraw_list(opt_id, key, event, _("A&ddresses"))

      nil
    end

    # Validate function of a popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    # @param [Hash] event map representing the event that caused validation
    # @return [Boolean] true if widget settings ok
    def ip_pair_array_validate(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      if Builtins.size(@entry_list) == 0
        # message popup
        Popup.Message(_("At least one address pair must be specified."))
        return false
      end
      true
    end

    # Initialize the settings in the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def flagInit(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = fetchValue(opt_id, key)
      UI.ChangeWidget(Id(key), :Value, value == "__true")

      nil
    end

    # Store function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    def flagStore(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = Convert.to_boolean(UI.QueryWidget(Id(key), :Value))
      storeValue(opt_id, key, value ? "__true" : "__false")

      nil
    end

    # Summary function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    # @return [String] value to be displayed in the table
    def flagSummary(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = fetchValue(opt_id, key)
      if value == "__true"
        # table item, means switched on
        return _("On")
      end
      # table item, means switched off
      _("Off")
    end

    # Initialize the settings in the popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def onoffInit(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = fetchValue(opt_id, key)
      UI.ChangeWidget(
        Id(key),
        :Value,
        Builtins.tolower(Convert.to_string(value)) == "on"
      )

      nil
    end

    # Store function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    def onoffStore(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = Convert.to_boolean(UI.QueryWidget(Id(key), :Value))
      storeValue(opt_id, key, value ? "on" : "off")

      nil
    end

    # Summary function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    # @return [String] value to be displayed in the table
    def onoffSummary(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = fetchValue(opt_id, key)
      if Builtins.tolower(Convert.to_string(value)) == "on"
        # table item, means switched on
        return _("On")
      end
      # table item, means switched off
      _("Off")
    end

    # Validate function of a popup
    # @param [Object] opt_id any option id
    # @param [String] key any option key
    # @param [Hash] event map representing the event that caused validation
    # @return [Boolean] true if widget settings ok
    def quoted_string_validate(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      value = Convert.to_string(UI.QueryWidget(Id(key), :Value))

      if Builtins.regexpmatch(value, "\"")
        value = Builtins.mergestring(Builtins.splitstring(value, "\""), "\\\"")
      end

      UI.ChangeWidget(Id(key), :Value, value)

      # UI::SetFocus (`id (key));
      true
    end

    def validate_value(id, key, event)
      id = deep_copy(id)
      event = deep_copy(event)
      if UI.WidgetExists(Id(key))
        value = UI.QueryWidget(Id(key), :Value)
        if value == ""
          # popup message
          Popup.Message(_("A value must be specified."))
          return false
        end
      end
      true
    end

    # Get popup description map for an option type
    # @return popup description map
    def uint8_widget
      { "widget" => :intfield, "minimum" => 0, "maximum" => 255 } # 2^8-1
    end

    # Get popup description map for an option type
    # @return popup description map
    def uint16_widget
      { "widget" => :intfield, "minimum" => 0, "maximum" => 65535 } # 2^16-1
    end

    # Get popup description map for an option type
    # @return popup description map
    def uint32_widget
      { "widget" => :intfield, "minimum" => 0, "maximum" => 4294967295 } # 2^32-1
    end

    # Get popup description map for an option type
    # @return popup description map
    def int32_widget
      {
        "widget"  => :intfield,
        "minimum" => -2147483648, # -2^31
        "maximum" => 2147483647
      } # 2^31-1
    end

    # Get popup description map for an option type
    # @return popup description map
    def text_widget
      {
        "widget" => :textentry,
        "init"   => fun_ref(method(:textWidgetInit), "void (any, string)"),
        "store"  => fun_ref(method(:textWidgetStore), "void (any, string)")
      }
    end

    # Get popup description map for an option type
    # @return popup description map
    def quoted_string_widget
      {
        "widget"            => :textentry,
        "init"              => fun_ref(
          method(:quoted_string_init),
          "void (any, string)"
        ),
        "store"             => fun_ref(
          method(:textWidgetStore),
          "void (any, string)"
        ),
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:quoted_string_validate),
          "boolean (any, string, map)"
        )
      }
    end

    # Get popup description map for an option type
    # @return popup description map
    def ip_address_widget
      {
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:ip_address_validate),
          "boolean (any, string, map)"
        )
      }
    end

    # Get popup description map for an option type
    # @return popup description map
    def array_ip_address_widget
      {
        "widget"            => :custom,
        "custom_widget"     => VBox(
          ReplacePoint(
            Id(:addresses_rp),
            # selection box
            SelectionBox(Id(:addresses), _("A&ddresses"), [])
          ),
          HBox(HStretch(), PushButton(Id(:delete), Label.DeleteButton)),
          HBox(
            # text entry
            TextEntry(Id(:new_addr), _("&New Address")),
            VBox(Label(""), PushButton(Id(:add), Label.AddButton))
          )
        ),
        "init"              => fun_ref(
          method(:ip_array_init),
          "void (any, string)"
        ),
        "store"             => fun_ref(
          method(:entry_array_store),
          "void (any, string)"
        ),
        "handle"            => fun_ref(
          method(:ip_array_handle),
          "void (any, string, map)"
        ),
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:ip_array_validate),
          "boolean (any, string, map)"
        )
      }
    end

    # Get popup description map for an option type
    # @return popup description map
    def array_uint16_widget
      {
        "widget"            => :custom,
        "custom_widget"     => VBox(
          ReplacePoint(
            Id(:addresses_rp),
            # selection box
            SelectionBox(Id(:addresses), _("&Values"), [])
          ),
          HBox(HStretch(), PushButton(Id(:delete), Label.DeleteButton)),
          HBox(
            # int field
            IntField(Id(:new_entry), _("&New Value"), 0, 65535, 0),
            VBox(Label(""), PushButton(Id(:add), Label.AddButton))
          )
        ),
        "init"              => fun_ref(
          method(:uint16_array_init),
          "void (any, string)"
        ),
        "store"             => fun_ref(
          method(:entry_array_store),
          "void (any, string)"
        ),
        "handle"            => fun_ref(
          method(:uint16_array_handle),
          "void (any, string, map)"
        ),
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:value_array_validate),
          "boolean (any, string, map)"
        )
      }
    end

    # Get popup description map for an option type
    # @return popup description map
    def array_ip_address_pair_widget
      {
        "widget"            => :custom,
        "custom_widget"     => VBox(
          ReplacePoint(
            Id(:addresses_rp),
            # selection box
            SelectionBox(Id(:addresses), _("A&ddresses"), [])
          ),
          HBox(HStretch(), PushButton(Id(:delete), Label.DeleteButton)),
          # label (in role of help text)
          Left(Label(_("Separate multiple addresses with spaces."))),
          HBox(
            # push button
            TextEntry(Id(:new_addr), _("&Add Address Pair")),
            VBox(Label(""), PushButton(Id(:add), Label.AddButton))
          )
        ),
        "init"              => fun_ref(
          method(:ip_array_init),
          "void (any, string)"
        ),
        "store"             => fun_ref(
          method(:entry_array_store),
          "void (any, string)"
        ),
        "handle"            => fun_ref(
          method(:ip_pair_array_handle),
          "void (any, string, map)"
        ),
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:ip_pair_array_validate),
          "boolean (any, string, map)"
        )
      }
    end

    # Initialization function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] opt_key string option key
    def hardwareInit(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      value = Convert.to_string(fetchValue(opt_id, opt_key))
      l = Builtins.splitstring(value, " ")
      l = Builtins.filter(l) { |i| i != "" }
      UI.ChangeWidget(Id(:addr), :Value, Ops.get(l, 1, ""))

      nil
    end


    # Store function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] opt_key string option key
    def hardwareStore(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      storeValue(
        opt_id,
        opt_key,
        "ethernet #{UI.QueryWidget(Id(:addr), :Value)}"
      )

      nil
    end

    # Validate function of a popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @param [Hash] event a map event to validate
    # @return [Boolean] true if widget settings ok
    def hardwareValidate(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      hosthwaddress = Convert.to_string(UI.QueryWidget(Id(:addr), :Value))

      if !Address.CheckMAC(hosthwaddress)
        Popup.Error(
          Ops.add(
            #error popup
            _("The hardware address is invalid.\n"),
            Address.ValidMAC
          )
        )
        UI.SetFocus(Id(:addr))
        return false
      end

      true
    end

    # Initialization function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def rangeInit(opt_id, key)
      opt_id = deep_copy(opt_id)
      value = Convert.to_string(fetchValue(opt_id, key))
      value = "" if value == nil
      l = Builtins.splitstring(value, " ")
      l = Builtins.filter(l) { |i| i != "" }
      lindex = 0
      if Ops.get(l, 0, "") == "dynamic-bootp"
        lindex = 1
        UI.ChangeWidget(Id(:bootp), :Value, true)
      end
      hindex = Ops.add(lindex, 1)
      UI.ChangeWidget(Id(:lower), :Value, Ops.get(l, lindex, ""))
      UI.ChangeWidget(Id(:upper), :Value, Ops.get(l, hindex, ""))

      nil
    end

    # Store function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    def rangeStore(opt_id, key)
      opt_id = deep_copy(opt_id)
      val = Builtins.sformat(
        "%1 %2",
        UI.QueryWidget(Id(:lower), :Value),
        UI.QueryWidget(Id(:upper), :Value)
      )
      if Convert.to_boolean(UI.QueryWidget(Id(:bootp), :Value))
        val = Builtins.sformat("dynamic-bootp %1", val)
      end
      storeValue(opt_id, key, val)

      nil
    end

    # Validate function of a popup
    # @param [Object] opt_id any option id
    # @param [String] key string option key
    # @param [Hash] event a map event to validate
    # @return [Boolean] true if widget settings ok
    def rangeValidate(opt_id, key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      lvalue = Convert.to_string(UI.QueryWidget(Id(:lower), :Value))
      if !Address.Check4(lvalue)
        Popup.Message(IP.Valid4)
        UI.SetFocus(Id(:lower))
        return false
      end
      uvalue = Convert.to_string(UI.QueryWidget(Id(:upper), :Value))
      if !Address.Check4(uvalue)
        Popup.Message(IP.Valid4)
        UI.SetFocus(Id(:upper))
        return false
      end
      if Ops.greater_than(IP.ToInteger(lvalue), IP.ToInteger(uvalue))
        # popup message
        Popup.Message(
          _("The lowest address must be lower than the highest one.")
        )
        UI.SetFocus(Id(:lower))
        return false
      end
      true
    end

    # Initialize popups
    # Create description map and copy it into appropriate variable of the
    #  DhcpServer module
    def InitPopups
      p = {
        "log-facility" => {
          "popup" => {
            # label -- help text
            "help" => _(
              "If you change this, also update the syslog configuration."
            )
          }
        },
        "hardware"     => {
          "popup" => {
            "widget"            => :custom,
            "custom_widget"     => VBox(
              # test entry, MAC better not to be translated,
              # translation would decrease the understandability
              TextEntry(Id(:addr), _("&MAC Address"))
            ),
            "init"              => fun_ref(
              method(:hardwareInit),
              "void (any, string)"
            ),
            "store"             => fun_ref(
              method(:hardwareStore),
              "void (any, string)"
            ),
            "validate_type"     => :function,
            "validate_function" => fun_ref(
              method(:hardwareValidate),
              "boolean (any, string, map)"
            )
          }
        },
        "flag"         => {
          "table" => {
            "summary" => fun_ref(method(:flagSummary), "string (any, string)")
          },
          "popup" => {
            "widget" => :checkbox,
            "init"   => fun_ref(method(:flagInit), "void (any, string)"),
            "store"  => fun_ref(method(:flagStore), "void (any, string)")
          }
        },
        "onoff"        => {
          "table" => {
            "summary" => fun_ref(method(:onoffSummary), "string (any, string)")
          },
          "popup" => {
            "widget" => :checkbox,
            "init"   => fun_ref(method(:onoffInit), "void (any, string)"),
            "store"  => fun_ref(method(:onoffStore), "void (any, string)")
          }
        },
        "range"        => {
          "popup" => {
            "widget"            => :custom,
            "custom_widget"     => VBox(
              HBox(
                # text entry
                TextEntry(Id(:lower), _("&Lowest IP Address")),
                # text entry
                TextEntry(Id(:upper), _("&Highest IP Address"))
              ),
              # checkbox
              CheckBox(Id(:bootp), _("Allow Dynamic &BOOTP"))
            ),
            "init"              => fun_ref(
              method(:rangeInit),
              "void (any, string)"
            ),
            "store"             => fun_ref(
              method(:rangeStore),
              "void (any, string)"
            ),
            "validate_type"     => :function,
            "validate_function" => fun_ref(
              method(:rangeValidate),
              "boolean (any, string, map)"
            )
          }
        }
      }

      options = Builtins.mapmap(@option_types) do |k, v|
        widget = Ops.get_map(@widget_types, v, {})
        if widget != {}
          if Ops.get(widget, "validate_type") == nil
            Ops.set(widget, "validate_type", :function)
            Ops.set(
              widget,
              "validate_function",
              fun_ref(method(:validate_value), "boolean (any, string, map)")
            )
          end
          entry = { "popup" => widget }
          next { k => entry }
        end
        next { k => Ops.get_map(p, v, {}) } if Builtins.haskey(p, v)
        { k => {} }
      end

      p = Builtins.union(options, p)

      @popups = deep_copy(p)

      nil
    end
  end
end
