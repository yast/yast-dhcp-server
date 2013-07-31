# encoding: utf-8

# File:	include/dhcp-server/dns-helps.ycp
# Package:	Configuration of dhcp-server
# Summary:	Help texts for DNS-Related dialogs
# Authors:	Lukas Ocilka <lukas.ocilka@novell.com>
#
# $Id$
module Yast
  module DhcpServerDnsHelpsInclude
    def initialize_dhcp_server_dns_helps(include_target)
      textdomain "dhcp-server"

      # TRANSLATORS:
      #     DNS Wizard - step 3 (part 4)
      #       and
      #     DNS for Experts (editing current settings) (part 5)
      @new_range_help = _(
        "<p><b><big>Adding a New Range of DNS Records</big></b><br />\n" +
          "<b>First IP Address</b> defines\n" +
          "the starting address of the range and <b>Last IP Address</b> defines\n" +
          "the last one. <b>Hostname Base</b> is a string that determines how hostnames\n" +
          "are created (such as <tt>dhcp-%i</tt> or <tt>e25-%i-a</tt>).\n" +
          "<tt>%i</tt> is replaced with the number of the host in the range.\n" +
          "If no <tt>%i</tt> is defined, the number is added at the end of the\n" +
          "string. <tt>%i</tt> can be used only once in <b>Hostname Base</b>.\n" +
          "<b>Start</b> defines the first number that is used for the first\n" +
          "hostname. Hostnames are created incrementally.</p>\n"
      )

      @DNS_HELPS = {
        # TRANSLATORS: DNS Wizard - step 1 (part 1)
        "wizard-zones"          => _(
          "<p><b><big>DNS Wizard</big></b><br />\n" +
            "In this wizard, create a new DNS zone\n" +
            "directly from the DHCP server configuration. This DNS zone is important\n" +
            "if you want to identify your DHCP clients by hostname. The DNS zone\n" +
            "translates names to the assigned IP addresses. You can also\n" +
            "create a reverse zone that translates IP addresses to names.</p>\n"
        ) +
          # TRANSLATORS: DNS Wizard - step 1 (part 2)
          _(
            "<p><b>New Zone Name</b> or <b>Reverse Zone Name</b>\nare taken from your current DHCP server and network settings and cannot be changed.</p>\n"
          ) +
          # TRANSLATORS: DNS Wizard - step 1 (part 3)
          _(
            "<p>Select <b>Also Create Reverse Zone</b> to create a zone \nto contain reverse entries of the main DNS zone.</p>\n"
          ),
        # TRANSLATORS: DNS Wizard - step 2 (part 1)
        "wizard-nameservers"    => _(
          "<p><big><b>Name Servers</b></big><br />\n" +
            "Name servers are needed for proper DNS server functionality.\n" +
            "They administer all the DNS zone records.</p>\n"
        ) +
          # TRANSLATORS: DNS Wizard - step 2 (part 2)
          _(
            "<p><b><big>DNS Queries</big></b><br />\n" +
              "Every DNS query (for example searching an IP address for a\n" +
              "hostname in a DNS zone) first asks the parent zone\n" +
              "(<tt>com</tt> for <tt>example.com</tt>) for the current zone\n" +
              "name servers. Then it sends a DNS query to these name servers requesting\n" +
              "the desired IP address.<br />\n" +
              "Therefore, always specify the current DNS server hostname as one of\n" +
              "the zone name servers.</p>\n"
          ) +
          # TRANSLATORS: DNS Wizard - step 2 (part 3)
          _(
            "<p>To add a <b>New Name Server</b>, click <b>Add</b>, complete the form,\n" +
              "then click <b>Ok</b>. If the new name server name is included in the current\n" +
              "DNS zone, also enter its IP address. This is mandatory because it is used\n" +
              "during the zone creation.</p>\n"
          ) +
          # TRANSLATORS: DNS Wizard - step 2 (part 4)
          _(
            "<p>To edit or delete an entry, select it and click\n<b>Edit</b> or <b>Delete</b>.</p>\n"
          ),
        # TRANSLATORS: DNS Wizard - step 3 (part 1)
        "wizard-ranges"         => Ops.add(
          Ops.add(
            _(
              "<p><b><big>DNS Records</big></b><br />\n" +
                "Define DNS hostnames for all DHCP clients. You do not need to define\n" +
                "all hostnames one by one. Set simple rules for how\n" +
                "the hostnames are created. These rules define the ranges of IP addresses to use\n" +
                "and the string from which hostnames are generated for a range.</p>\n"
            ) +
              # TRANSLATORS: DNS Wizard - step 3 (part 2)
              _(
                "<p><b><big>Range of DNS Records</big></b><br />\n" +
                  "For example, create a set of hostnames from <tt>dhcp-133-a</tt>\n" +
                  "to <tt>dhcp-233-a</tt> with IP addresses from <tt>192.168.5.88</tt>\n" +
                  "to <tt>192.168.5.188</tt>.</p>\n"
              ) +
              # TRANSLATORS: DNS Wizard - step 3 (part 3)
              _(
                "<p>To add a new range of DNS records, click <b>Add</b>,\ncomplete the form, then click <b>Ok</b>.</p>\n"
              ),
            # TRANSLATORS: DNS Wizard - step 3 (part 4)
            @new_range_help
          ),
          # TRANSLATORS: DNS Wizard - step 3 (part 5)
          _(
            "<p>To edit or delete an entry, select it and click\n<b>Edit</b> or <b>Delete</b>.</p>\n"
          )
        ),
        # TRANSLATORS: DNS Wizard - summary (part 1)
        "wizard-summary"        => _(
          "<p>This is a summary of all data\nentered in the configuration wizard so far.</p>\n"
        ) +
          # TRANSLATORS: DNS Wizard - summary (part 2)
          _(
            "<p>Click <b>Accept</b> to save the settings for\n" +
              "the DNS server and return to the DHCP server configuration.\n" +
              "The settings are not saved permanently until you complete the \n" +
              "DHCP server configuration.</p>\n"
          ),
        # TRANSLATORS: DNS for Experts (editing current settings) (part 1)
        "edit-current-settings" => Ops.add(
          _(
            "<p><b><big>DNS Synchronization</big></b><br />\n" +
              "This is an advanced tool for editing DNS server settings to match your\n" +
              "DHCP settings. Only 'A' records--DNS records that convert hostnames to\n" +
              "IP addresses--are maintained here.</p>\n"
          ) +
            # TRANSLATORS: DNS for Experts (editing current settings) (part 2)
            _(
              "<b>Current Subnet</b> and <b>Netmask</b> show the current network settings.\n" +
                "<b>Domain</b> is taken from the current DHCP configuration.\n" +
                "<b>First IP Address</b> and <b>Second IP Address</b> match the current\n" +
                "Dynamic DHCP range.</p>\n"
            ) +
            # TRANSLATORS: DNS for Experts (editing current settings) (part 3)
            _(
              "<p>\n" +
                "To create a DNS zone from scratch, use <b>Run Wizard</b>\n" +
                "from <b>Special Tasks</b>.</p>\n"
            ) +
            # TRANSLATORS: DNS for Experts (editing current settings) (part 4)
            _(
              "<p>\n" +
                " To create or remove a single DNS record,\n" +
                "click <b>Add</b> or <b>Delete</b>.\n" +
                "To synchronize the DNS entries with their reverse forms in the corresponding\n" +
                "reverse zone, select <b>Synchronize with Reverse Zone</b>.\n" +
                "Use <b>Remove DNS Records Matching Range</b> \n" +
                "from <b>Special Tasks</b> to delete any information relating to this range of IP addresses from the DNS server. To create a new range of DNS records, select\n" +
                "<b>Add New Range of DNS Records</b> from <b>Special Tasks</b>.</p>\n"
            ),
          # TRANSLATORS: DNS for Experts (editing current settings) (part 5)
          @new_range_help
        )
      } 

      # EOF
    end
  end
end
