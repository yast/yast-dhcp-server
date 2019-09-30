# encoding: utf-8

# File:	clients/dhcp-server.ycp
# Package:	Configuration of dhcp-server
# Summary:	Main file
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# Main file for dhcp-server configuration. Uses all other files.
module Yast
  module DhcpServerCommandlineInclude
    def initialize_dhcp_server_commandline(include_target)
      Yast.import "CommandLine"
      Yast.import "DhcpServer"
      Yast.import "NetworkInterfaces"

      textdomain "dhcp-server"

      Yast.include include_target, "dhcp-server/misc.rb"

      @cmdline = {
        "id"         => "dhcp-server",
        # command line help text for DHCP server module
        "help"       => _(
          "DHCP server configuration module"
        ),
        "guihandler" => fun_ref(method(:GuiHandler), "boolean ()"),
        "initialize" => fun_ref(DhcpServer.method(:Read), "boolean ()"),
        "finish"     => fun_ref(DhcpServer.method(:Write), "boolean ()"),
        "actions"    => {
          "status"    => {
            "handler" => fun_ref(method(:StatusHandler), "boolean (map)"),
            # command line help text for an action
            "help"    => _(
              "Print the status of the DHCP server"
            )
          },
          "enable"    => {
            "handler" => fun_ref(method(:EnableHandler), "boolean (map)"),
            # command line help text for an action
            "help"    => _(
              "Enable the DHCP server"
            )
          },
          "disable"   => {
            "handler" => fun_ref(method(:DisableHandler), "boolean (map)"),
            # command line help text for an action
            "help"    => _(
              "Disable the DHCP server"
            )
          },
          "host"      => {
            "handler" => fun_ref(method(:HostHandler), "boolean (map)"),
            # command line help text for an action
            "help"    => _(
              "Manage individual host settings"
            )
          },
          "interface" => {
            "handler" => fun_ref(method(:InterfaceHandler), "boolean (map)"),
            # command line help text for an action
            "help"    => _(
              "Select the network interface to listen to"
            )
          },
          "options"   => {
            "handler" => fun_ref(method(:OptionsHandler), "boolean (map)"),
            # command line help text for an action
            "help"    => _(
              "Manage global DHCP options"
            )
          },
          "subnet"    => {
            "handler" => fun_ref(method(:SubnetHandler), "boolean (map)"),
            # command line help text for an action
            "help"    => _(
              "Manage DHCP subnet options"
            )
          }
        },
        "options"    => {
          "list"               => {
            # command line help text for an option
            "help" => _(
              "List all defined hosts with a fixed address"
            )
          },
          "add"                => {
            # command line help text for an option
            "help" => _(
              "Add a new host with a fixed address"
            )
          },
          "edit"               => {
            # command line help text for an option
            "help" => _(
              "Edit a host with a fixed address"
            )
          },
          "delete"             => {
            # command line help text for an option
            "help" => _(
              "Delete a host with a fixed address"
            )
          },
          "name"               => {
            # command line help text for an option
            "help" => _(
              "The name of the host with a fixed address"
            ),
            "type" => "string"
          },
          "hardware-address"   => {
            # command line help text for an option
            "help" => _(
              "The hardware address of the host with a fixed address"
            ),
            "type" => "string"
          },
          "hardware-type"      => {
            # command line help text for an option
            "help"     => _(
              "The hardware type of the host with a fixed address"
            ),
            "type"     => "enum",
            "typespec" => ["ethernet", "token-ring"]
          },
          "ip-address"         => {
            # command line help text for an option
            "help" => _(
              "The IP address (or hostname) of the host with a fixed address"
            ),
            "type" => "string"
          },
          "select"             => {
            # command line help text for an option
            "help" => _(
              "Select the network interface to use"
            ),
            "type" => "string"
          },
          "current"            => {
            # command line help text for an option
            "help" => _(
              "Print the currently used interface and list other available interfaces"
            )
          },
          "print"              => {
            # command line help text for an option
            "help" => _(
              "Print current options"
            )
          },
          "set"                => {
            # command line help text for an option
            "help" => _(
              "Set a global option"
            )
          },
          "key"                => {
            # command line help text for an option
            "help" => _(
              "Option key (for example, ntp-servers)"
            ),
            "type" => "string"
          },
          "value"              => {
            # command line help text for an option
            "help" => _(
              "Option value (for example, IP address)"
            ),
            "type" => "string"
          },
          "min-ip"             => {
            # command line help text for an option
            "help" => _(
              "Lowest IP address of the dynamic address assigning range"
            ),
            "type" => "ip4"
          },
          "max-ip"             => {
            # command line help text for an option
            "help" => _(
              "Highest IP address of the dynamic address assigning range"
            ),
            "type" => "ip4"
          },
          "default-lease-time" => {
            # command line help text for an option
            "help" => _(
              "Default lease time in seconds"
            ),
            "type" => "integer"
          },
          "max-lease-time"     => {
            # command line help text for an option
            "help" => _(
              "Maximum lease time in seconds"
            ),
            "type" => "integer"
          }
        },
        "mappings"   => {
          "status"    => [],
          "enable"    => [],
          "disable"   => [],
          "host"      => [
            "add",
            "edit",
            "delete",
            "list",
            "name",
            "hardware-address",
            "hardware-type",
            "ip-address"
          ],
          "interface" => ["select", "current"],
          "options"   => ["print", "set", "key", "value"],
          "subnet"    => [
            "print",
            "min-ip",
            "max-ip",
            "default-lease-time",
            "max-lease-time"
          ]
        }
      }
    end

    # Handler for command line interface
    # @param [Hash] options map options from the command line
    # @return [Boolean] true if settings have been changed
    def StatusHandler(options)
      options = deep_copy(options)
      CommandLine.Print(
        DhcpServer.GetStartService ?
          # status information for command line
          _("DHCP server is enabled") :
          # status information for command line
          _("DHCP server is disabled")
      )
      false
    end

    # Handler for command line interface
    # @param [Hash] options map options from the command line
    # @return [Boolean] true if settings have been changed
    def EnableHandler(options)
      options = deep_copy(options)
      DhcpServer.SetStartService(true)
      true
    end

    # Handler for command line interface
    # @param [Hash] options map options from the command line
    # @return [Boolean] true if settings have been changed
    def DisableHandler(options)
      options = deep_copy(options)
      DhcpServer.SetStartService(false)
      true
    end

    # Handler for command line interface
    # @param [Hash] options map options from the command line
    # @return [Boolean] true if settings have been changed
    def HostHandler(options)
      options = deep_copy(options)
      ifaces = DhcpServer.GetAllowedInterfaces
      # we assume there is only a single interface at this stage
      interface = Ops.get(ifaces, 0)

      m = DhcpServer.GetInterfaceInformation(interface)
      hosts_parent_id = Ops.add(
        Ops.add(Ops.get_string(m, "network", ""), " netmask "),
        Ops.get_string(m, "netmask", "")
      )
      Builtins.y2milestone("Id to take hosts from: %1", hosts_parent_id)
      if !DhcpServer.EntryExists("subnet", hosts_parent_id)
        DhcpServer.CreateEntry("subnet", hosts_parent_id, "", "")
      end

      if Builtins.haskey(options, "list")
        printed = false

        children = DhcpServer.GetChildrenOfEntry("subnet", hosts_parent_id)
        Builtins.foreach(children) do |child|
          if Ops.get(child, "type") == "host"
            CommandLine.Print("") if printed
            host = Ops.get(child, "id", "")

            directives = DhcpServer.GetEntryDirectives("host", host)
            # command-line text output, %1 is host name
            CommandLine.Print(Builtins.sformat(_("Host: %1"), host))
            Builtins.foreach(directives) do |opt|
              if Ops.get(opt, "key") == "hardware"
                # command-line text output, %1 is hardwarre address
                # and hardware type (eg. "ethernet 11:22:33:44:55:66")
                CommandLine.Print(
                  Builtins.sformat(_("Hardware: %1"), Ops.get(opt, "value", ""))
                )
              elsif Ops.get(opt, "key") == "fixed-address"
                # command-line text output, %1 is IP address
                CommandLine.Print(
                  Builtins.sformat(
                    _("IP Address: %1"),
                    Ops.get(opt, "value", "")
                  )
                )
              end
            end
            printed = true
          end
        end
        return false
      end

      name = Ops.get_string(options, "name")
      if name == nil
        # command-line error report
        CommandLine.Error(_("Hostname not specified."))
        return false
      end


      if Builtins.haskey(options, "add") || Builtins.haskey(options, "edit")
        if Builtins.haskey(options, "add")
          DhcpServer.CreateEntry("host", name, "subnet", hosts_parent_id)
        elsif !DhcpServer.EntryExists("host", name)
          # command-line error report
          CommandLine.Error(_("Specified host does not exist."))
          return false
        end

        directives = DhcpServer.GetEntryDirectives("host", name)
        if Builtins.haskey(options, "hardware-address") &&
            Builtins.haskey(options, "hardware-type")
          directives = Builtins.filter(directives) do |d|
            Ops.get(d, "key", "") != "hardware"
          end
          val = Builtins.sformat(
            "%1 %2",
            Ops.get_string(options, "hardware-type", ""),
            Ops.get_string(options, "hardware-address", "")
          )
          directives = Builtins.add(
            directives,
            { "key" => "hardware", "value" => val }
          )
        end
        if Builtins.haskey(options, "ip-address")
          directives = Builtins.filter(directives) do |d|
            Ops.get(d, "key", "") != "fixed-address"
          end
          directives = Builtins.add(
            directives,
            {
              "key"   => "fixed-address",
              "value" => Ops.get_string(options, "ip-address", "")
            }
          )
        end

        DhcpServer.SetEntryDirectives("host", name, directives)
        return true
      end

      if Builtins.haskey(options, "delete")
        DhcpServer.DeleteEntry("host", name)
        return true
      end
      false
    end

    # Handler for command line interface
    # @param [Hash] options map options from the command line
    # @return [Boolean] true if settings have been changed
    def InterfaceHandler(options)
      options = deep_copy(options)
      NetworkInterfaces.Read
      all_interfaces = NetworkInterfaces.List("")
      all_interfaces = Builtins.filter(all_interfaces) { |i| i != "lo" }
      dhcp_ifaces = DhcpServer.GetAllowedInterfaces
      other_ifaces = Builtins.filter(all_interfaces) do |i|
        !Builtins.contains(dhcp_ifaces, i)
      end
      if Builtins.haskey(options, "current")
        selected = Builtins.mergestring(dhcp_ifaces, ", ")
        other = Builtins.mergestring(other_ifaces, ", ")
        if selected == ""
          # to be eventually pasted to "Selected interfaces: %1"
          selected = _("None")
        end
        if other == ""
          # to be eventually pasted to "Other interfaces: %1"
          other = _("None")
        end
        # command-line text output, %1 is list of network interfaces
        CommandLine.Print(
          Builtins.sformat(_("Selected Interfaces: %1"), selected)
        )
        # command-line text output, %1 is list of network interfaces
        CommandLine.Print(Builtins.sformat(_("Other Interfaces: %1"), other))
        return false
      end
      if Builtins.haskey(options, "select")
        old_iface = Ops.get(dhcp_ifaces, 0, "")
        new_iface = Ops.get_string(options, "select", "")
        if !Builtins.contains(all_interfaces, new_iface)
          # command-line error report
          CommandLine.Print(_("Specified interface does not exist."))
          return false
        end
        UpdateSubnetDeclaration(old_iface, new_iface) if old_iface != ""
        DhcpServer.SetAllowedInterfaces([new_iface])
        DhcpServer.SetModified
        return true
      end
      # command-line error report
      CommandLine.Print(_("Operation with the interface not specified."))
      false
    end

    # Handler for command line interface
    # @param [Hash] options map options from the command line
    # @return [Boolean] true if settings have been changed
    def OptionsHandler(options)
      options = deep_copy(options)
      if Builtins.haskey(options, "print")
        # get the global options
        options2 = DhcpServer.GetEntryOptions("", "")
        options2 = [] if options2 == nil

        Builtins.foreach(options2) do |opt|
          key = Ops.get(opt, "key", "")
          value = Ops.get(opt, "value", "")
          CommandLine.Print(Builtins.sformat("%1 = %2", key, value))
        end
        return false
      end
      if Builtins.haskey(options, "set")
        key = Ops.get_string(options, "key", "")
        value = Ops.get_string(options, "value", "")
        if key == ""
          # command-line error report
          CommandLine.Print(_("Option key must be set."))
          return false
        end
        if value == ""
          # command-line error report
          CommandLine.Print(_("Value must be set."))
          return false
        end
        options2 = DhcpServer.GetEntryOptions("", "")
        options2 = [] if options2 == nil
        options2 = Builtins.filter(options2) { |o| Ops.get(o, "key", "") != key }
        options2 = Builtins.add(options2, { "key" => key, "value" => value })
        DhcpServer.SetEntryOptions("", "", options2)
        return true
      end
      false
    end

    # Handler for command line interface
    # @param [Hash] options map options from the command line
    # @return [Boolean] true if settings have been changed
    def SubnetHandler(options)
      options = deep_copy(options)
      ifaces = DhcpServer.GetAllowedInterfaces
      if Builtins.size(ifaces) == 0
        Builtins.y2error("No interfaces set")
        return false
      end
      interface = Ops.get(ifaces, 0)
      m = DhcpServer.GetInterfaceInformation(interface)
      id = Ops.add(
        Ops.add(Ops.get_string(m, "network", ""), " netmask "),
        Ops.get_string(m, "netmask", "")
      )
      Builtins.y2milestone("Id to lookup: %1", id)
      if !DhcpServer.EntryExists("subnet", id)
        DhcpServer.CreateEntry("subnet", id, "", "")
      end

      directives = DhcpServer.GetEntryDirectives("subnet", id)
      directives = [] if directives == nil

      if Builtins.haskey(options, "print")
        Builtins.foreach(directives) do |opt|
          if Ops.get(opt, "key") == "range"
            range = Builtins.splitstring(Ops.get(opt, "value", ""), " ")
            # command-line output text, %1  and %1 are IP addresses
            CommandLine.Print(
              Builtins.sformat(
                _("Address Range: %1-%2"),
                Ops.get(range, 0, ""),
                Ops.get(range, 1, "")
              )
            )
          elsif Ops.get(opt, "key") == "default-lease-time"
            # command-line output text, %1 is integer
            CommandLine.Print(
              Builtins.sformat(
                _("Default Lease Time: %1"),
                Ops.get(opt, "value")
              )
            )
          elsif Ops.get(opt, "key") == "max-lease-time"
            # command-line output text, %1 is integer
            CommandLine.Print(
              Builtins.sformat(
                _("Maximum Lease Time: %1"),
                Ops.get(opt, "value")
              )
            )
          end
        end
        return false
      end

      save = false
      Builtins.foreach(["default-lease-time", "max-lease-time"]) do |key|
        if Builtins.haskey(options, key)
          save = true
          directives = Builtins.filter(directives) do |d|
            Ops.get(d, "key", "") != key
          end
          directives = Builtins.add(
            directives,
            { "key" => key, "value" => Ops.get_string(options, key, "") }
          )
        end
      end
      if Builtins.haskey(options, "min-ip") ||
          Builtins.haskey(options, "max-ip")
        save = true
        range = ""
        directives = Builtins.filter(directives) do |d|
          if Ops.get(d, "key", "") == "range"
            range = Ops.get(d, "value", "")
            next false
          end
          true
        end
        Builtins.y2error("Range: %1", range)
        range_l = Builtins.splitstring(range, " ")
        Builtins.y2error("Range: %1", range_l)
        if Builtins.haskey(options, "min-ip")
          Ops.set(range_l, 0, Ops.get_string(options, "min-ip", ""))
        end
        if Builtins.haskey(options, "max-ip")
          Ops.set(range_l, 1, Ops.get_string(options, "max-ip", ""))
        end
        range = Builtins.mergestring(range_l, " ")
        Builtins.y2error("Range: %1", range)
        directives = Builtins.add(
          directives,
          { "key" => "range", "value" => range }
        )
      end
      if save
        DhcpServer.SetEntryDirectives("subnet", id, directives)
        return true
      end

      false
    end
  end
end
