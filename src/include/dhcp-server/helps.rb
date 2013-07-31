# encoding: utf-8

# File:	include/dhcp-server/helps.ycp
# Package:	Configuration of dhcp-server
# Summary:	Help texts of all the dialogs
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
module Yast
  module DhcpServerHelpsInclude
    def initialize_dhcp_server_helps(include_target)
      textdomain "dhcp-server"

      @HELPS = {
        # help text 1/1
        "read"                  => _(
          "<p><b><big>Initializing DHCP Server Configuration</big></b><br>\nPlease wait...</p>"
        ),
        # help text 1/1
        "write"                 => _(
          "<p><b><big>Saving DHCP Server Configuration</big></b><br>\nPlease wait...</p>"
        ),
        # help text 1/2
        "interfaces"            => _(
          "<p><b><big>Network Interfaces</big></b><br>\n" +
            "Select the network interfaces to which the DHCP server should listen from\n" +
            "<b>Available Interfaces</b>.</p>"
        ),
        # help text 2/2
        "open_firewall"         => _(
          "<p><b><big>Firewall Settings</big></b><br>\n" +
            "To open the firewall to allow access to the service from \n" +
            "remote computers through the selected interface, set\n" +
            "<b>Open Firewall for Selected Interface</b>. \n" +
            "This option is only available if the firewall\n" +
            "is enabled.</p>"
        ),
        # help text 1/5
        "start"                 => _(
          "<p><b><big>DHCP Server</big></b></p>\n" +
            "<p>To run the DHCP server every time your computer is started, set\n" +
            "<b>Start DHCP Server</b>.</p>"
        ),
        # help text 2/5
        "chroot"                => _(
          "<p>\n" +
            "To run the DHCP server in chroot jail, set\n" +
            "<b>Run DHCP Server in Chroot Jail</b>. Starting any daemon in a chroot jail\n" +
            "is more secure and strongly recommended.</p>"
        ),
        # help text 3/5
        "ldap_support"          => _(
          "<p>\n" +
            "To store the DHCP configuration in LDAP,\n" +
            "enable <b>LDAP Support</b>.</p>"
        ),
        # help text 4/5
        "configtree"            => _(
          "<p><b>Configured Declarations</b> shows the configuration options in use.\n" +
            "To modify an existing declaration, select it and click <b>Edit</b>.\n" +
            "To add a new declaration, select a declaration that should include\n" +
            "the new declaration and click <b>Add</b>.\n" +
            "To delete a declaration, select it and click <b>Delete</b>.</p>"
        ) +
          # help text 5/5
          _(
            "<p><b><big>Advanced Functions</big></b><br>\n" +
              "Use <b>Advanced</b> to display the log of the DHCP server,\n" +
              "change network interfaces to which the DHCP server listens,\n" +
              "or manage TSIG keys that can be used for authentication of \n" +
              "dynamic DNS updates.</p>"
          ),
        # help text 1/3, alt. 1
        "subnet"                => _(
          "<p><b><big>Subnet Configuration</big></b><br>\nSet the <b>Network Address</b> and <b>Network Mask</b> of the subnet.</p>"
        ),
        # help text 1/3, alt. 1
        "host"                  => _(
          "<p><b><big>Host with Fixed Address</big></b><br>\n" +
            "Set the name of the host for which to set the fixed address or other\n" +
            "special options in <b>Hostname</b>.</p>"
        ),
        # help text 1/3, alt. 3
        "group"                 => _(
          "<p><b><big>Group-Specific Options</big></b><br>\n" +
            "Set the name of the group of declarations in <b>Group Name</b>.  \n" +
            "It is just for your identification.\n" +
            "The name does not affect behavior of the DHCP server.</p>"
        ),
        # help text 1/3, alt. 4
        "pool"                  => _(
          "<p><b><big>Pool of Addresses</big></b><br>\n" +
            "Set the name of the pool of addresses in <b>Pool Name</b>. \n" +
            "It is just for your identification.\n" +
            "The name does not affect behavior of the DHCP server.</p>"
        ),
        # help text 1/3, alt. 5
        "shared-network"        => _(
          "<p><b><big>Shared Network</big></b><br>\n" +
            "Set the name for the shared network in <b>Shared Network Name</b>. \n" +
            "It is just for your identification.\n" +
            "The name does not affect behavior of the DHCP server.</p>"
        ),
        # help text 1/3, alt. 6
        "class"                 => _(
          "<p><b><big>Class</big></b><br>\nSet the name of the class of hosts in <b>Class Name</b>.</p>"
        ),
        # help text 2/3
        "options_table"         => _(
          "<p>\n" +
            "To edit DHCP options, choose the appropriate\n" +
            "entry of the table then click <b>Edit</b>.\n" +
            "To add a new option, use <b>Add</b>. To remove\n" +
            "an option, select it and click <b>Delete</b>.</p>"
        ),
        # help text 3/3
        "dyn_dns_button"        => _(
          "<p>\nTo adjust dynamic DNS for hosts of this subnet, use <b>Dynamic DNS</b>.</p>"
        ),
        # help text 1/4
        "enable_ddns"           => _(
          "<p><b><big>Enabling Dynamic DNS</big></b><br>\n" +
            "To enable Dynamic DNS updates for this subnet, set\n" +
            "<b>Enable Dynamic DNS for This Subnet</b>.</p>"
        ) +
          # help text 2/4
          _(
            "<p><b><big>TSIG Key</big></b><br>\n" +
              "To make Dynamic DNS updates, the authentication key must be set. Use\n" +
              "<b>TSIG Key</b> to select the key to use for authentication. The key must\n" +
              "be the same for both DHCP and DNS servers. Specify the key for both forward\n" +
              "and reverse zone.</p>"
          ) +
          # help text 3/4
          _(
            "<p><b><big>Global DHCP Server Settings</big></b><br>\n" +
              "Global settings of DHCP server must be updated to make Dynamic\n" +
              "DNS work properly. To do it automatically, set\n" +
              "<b>Update Global Dynamic DNS Settings</b>.</p>"
          ),
        # help text 4/4
        "ddns_zones"            => _(
          "<p><b><big>Zones to Update</big></b><br>\n" +
            "Specify forward and reverse zones to update. For both, also specify \n" +
            "their primary name server. If the name server runs on the same host as the DHCP\n" +
            "server, you can leave the fields empty.</p>"
        ),
        # help text
        "other_options"         => _(
          "<p><b><big>DHCP Server Start-Up Arguments</big></b><br>\n" +
            "Here you can specify parameters that you want DHCP Server to be started with \n" +
            "(e.g. \"-p 1234\") for a non-standard port to listen on). For all possible options,\n" +
            "consult dhcpd manual page. If left blank, default values will be used.</p>"
        ),
        # Wizard Installation - Step 1 (version for expert UI)
        "card_selection_expert" => _(
          "<p><b><big>Network Card Selection</big></b><br>\nSelect one or more of the listed network cards to use for the DHCP server.</p>\n"
        ),
        #Optional field - used with LDAP support
        "ldap_server_name"      => _(
          "Optionally, you can also specify <b>DHCP Server Name</b>\n(the name of dhcpServer LDAP object), if it differs from your hostname.\n"
        ),
        # Wizard Installation - Step 2 1/9
        "global_settings"       => _(
          "<p><b><big>Global Settings</big></b><br>\nHere, make several DHCP settings.</p>"
        ) +
          # Wizard Installation - Step 2 2/9


          # Wizard Installation - Step 2 3/9 (2 is removed)
          _(
            "<p><b>Domain Name</b> sets the domain for which the DHCP server\nleases IPs to clients.</p>"
          ) +
          # Wizard Installation - Step 2 4/9
          _(
            "<p><b>Primary Name Server IP</b> and <b>Secondary Name Server IP</b> \n" +
              "offer these name servers to the DHCP clients.\n" +
              "These values must be IP addresses.</p>"
          ) +
          # Wizard Installation - Step 2 5/9
          _(
            "<p><b>Default Gateway</b> inserts this\nvalue as the default route in the routing table of clients.</p>"
          ) +
          # Wizard Installation - Step 2 6/9
          _(
            "<p><b>Time Server</b> tells clients to use this server\nfor time synchronization.</p>"
          ) +
          # Wizard Installation - Step 2 7/9
          _(
            "<p><b>Print Server</b> offers this server as the default print server.</p>"
          ) +
          # Wizard Installation - Step 2 8/9
          _(
            "<p><b>WINS Server</b> offers this server as the WINS server\n(Windows Internet Naming Service).</p>"
          ) +
          # Wizard Installation - Step 2 9/9
          _(
            "<p><b>Default Lease Time</b> sets the time after which the leased IP expires\nand the client must ask for an IP again.</p>"
          ),
        # Wizard Installation - Step 3 1/4
        "dynamic_dhcp"          => _(
          "<p><b><big>Subnet Information</big></b></br>\n" +
            "View information about the current subnet, such as its address,\n" +
            "netmask, minimum and maximum IP addresses available for the clients.\n" +
            "</p>\n"
        ) +
          # Wizard Installation - Step 3 2/4
          _(
            "<p><b><big>IP Address Range</big></b><br>\n" +
              "Set the <b>First IP Address</b> and the <b>Last IP Address</b>\n" +
              "of the address range to be leased to clients. These addresses must have the same netmask.\n" +
              "For instance, <tt>192.168.1.1</tt> and <tt>192.168.1.64</tt>. Check the <b>\n" +
              "Allow Dynamic BOOTP</b> flag if the specified range may be dynamically\n" +
              "assigned to BOOTP clients as well as DHCP clients</p>.\n"
          ) +
          # Wizard Installation - Step 3 3/4
          _(
            "<p><b><big>Lease Time</big></b><br>\n" +
              "Set the <b>Default</b> lease time for the current IP address range,\n" +
              "which sets the optimal IP refreshing time for clients.<br></p>"
          ) +
          # Wizard Installation - Step 3 4/4
          _(
            "<p><b>Maximum</b> (optional value) sets the maximum time period\nfor which this IP is blocked for the client on the DHCP server.</p>"
          ),
        # Help text
        "all_settings_button"   => _(
          "<p><b><big>Expert Configuration</big></b><br>\n" +
            "To enter the complete configuration of the DHCP server, click\n" +
            "<b>DHCP Server Expert Configuration</b>.</p>"
        ),
        # help text 1/2
        "interfaces"            => _(
          "<p><b><big>Network Interfaces</big></b><br>\n" +
            "Select the network interfaces to which the DHCP server should listen from\n" +
            "<b>Available Interfaces</b>.</p>"
        ),
        # host management help 1/3
        "host_management"       => _(
          "<p><b><big>Host Management</big></b><br>\nUse this dialog to edit hosts with static address binding.</p>"
        ) +
          # host management help 1/3
          _(
            "<p>To add a new new host, set its <b>Name</b>,\n" +
              "<b>Hardware Address</b>, and <b>IP Address</b>\n" +
              "then click <b>Add</b>.</p>\n" +
              "<p>To modify a configured host, select it in the table,\n" +
              "change all values, and click <b>Change in List</b>.</p>"
          ) +
          # host management help 1/3
          _(
            "<p>To remove a host, select it and click <b>Delete from List</b>.</p>"
          )
      }
    end

    # Get help for declaration type seleciton
    # @param [Array] possible list of declarations that can be selected
    # @return [String] the help
    def getSelectDeclarationTypeHelp(possible)
      possible = deep_copy(possible)
      # help text 1/7
      ret = _("<p>Select the type of declaration to add.</p>")

      if Builtins.contains(possible, "subnet")
        # help text 2/7, optional
        ret = Ops.add(
          ret,
          _("<p>To add a network declaration,\nselect <b>Subnet</b>.</p>")
        )
      end
      if Builtins.contains(possible, "host")
        # help text 3/7, optional
        ret = Ops.add(
          ret,
          _(
            "<p>To add a host that needs special parameters\n(usually a fixed address), select <b>Host</b>.</p>"
          )
        )
      end
      if Builtins.contains(possible, "shared-network")
        # help text 4/7, optional
        ret = Ops.add(
          ret,
          _(
            "<p>To add a shared network (physical network with\nmultiple logical networks), select <b>Shared Network</b>.</p>"
          )
        )
      end
      if Builtins.contains(possible, "group")
        # help text 5/7, optional
        ret = Ops.add(
          ret,
          _(
            "<p>To add a group of other declarations (usually\nif they should share some settings), select <b>Group</b>.</p>"
          )
        )
      end
      if Builtins.contains(possible, "pool")
        # help text 6/7, optional
        ret = Ops.add(
          ret,
          _(
            "<p>To add a pool of addresses that will be treated\n" +
              "differently than other address pools although they are in the same\n" +
              "subnet, select <b>Pool of Addresses</b>.</p>"
          )
        )
      end
      if Builtins.contains(possible, "class")
        # help text 7/7, optional
        ret = Ops.add(
          ret,
          _(
            "<p>To create a condition class that can be used for\n" +
              "handling clients differently depending on the class to which they belong,\n" +
              "select <b>Class</b>.</p>"
          )
        )
      end
      ret
    end
  end
end
