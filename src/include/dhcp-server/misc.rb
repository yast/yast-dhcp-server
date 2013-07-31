# encoding: utf-8

# File:	include/dhcp-server/misc.ycp
# Package:	Configuration of DHCP server
# Summary:	Misc. functions
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
module Yast
  module DhcpServerMiscInclude
    def initialize_dhcp_server_misc(include_target)
      textdomain "dhcp-server"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "DhcpServer"
    end

    def UpdateSubnetDeclaration(old_iface, new_iface)
      old = DhcpServer.GetInterfaceInformation(old_iface)
      Builtins.y2error("Old: %1", old)
      new = DhcpServer.GetInterfaceInformation(new_iface)
      Builtins.y2error("New: %1", new)
      old_id = Ops.add(
        Ops.add(Ops.get_string(old, "network", ""), " netmask "),
        Ops.get_string(old, "netmask", "")
      )
      new_id = Ops.add(
        Ops.add(Ops.get_string(new, "network", ""), " netmask "),
        Ops.get_string(new, "netmask", "")
      )
      Builtins.y2error("Old: %1", old_id)
      Builtins.y2error("New: %1", new_id)
      return true if !DhcpServer.ExistsEntry("subnet", old_id)
      DhcpServer.ChangeEntry("subnet", old_id, "subnet", new_id)
    end
  end
end
