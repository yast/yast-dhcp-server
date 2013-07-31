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
  class DhcpServerClient < Client
    def main
      #**
      # <h3>Configuration of the dhcp-server</h3>

      textdomain "dhcp-server"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Dhcp-server module started")

      Yast.import "DhcpServerUI"

      Yast.include self, "dhcp-server/commandline.rb"
      @ret = CommandLine.Run(@cmdline)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Dhcp-server module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # CommandLine handler for running GUI
    # @return [Boolean] true if settings were saved
    def GuiHandler
      ret = DhcpServerUI.DhcpSequence
      return false if ret == :abort || ret == :back || ret == :nil
      true
    end
  end
end

Yast::DhcpServerClient.new.main
