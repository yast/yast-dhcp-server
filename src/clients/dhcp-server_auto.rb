# encoding: utf-8

# File:	clients/dhcp-server_auto.ycp
# Package:	Configuration of dhcp-server
# Summary:	Client for autoinstallation
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param function to execute
# @param map/list of dhcp-server settings
# @return [Hash] edited settings, Summary or boolean on success depending on called function
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallFunction ("dhcp-server_auto", [ "Summary", mm ]);
module Yast
  class DhcpServerAutoClient < Client
    def main

      textdomain "dhcp-server"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("DhcpServer auto started")

      Yast.import "DhcpServer"
      Yast.import "DhcpServerUI"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      # Create a summary
      if @func == "Summary"
        @ret = Ops.get(DhcpServer.Summary([]), 0, "")
      # Reset configuration
      elsif @func == "Reset"
        DhcpServer.Import({})
        @ret = {}
      # Were the settings modified?
      elsif @func == "GetModified"
        @ret = DhcpServer.GetModified
      # Mark settings as modified
      elsif @func == "SetModified"
        DhcpServer.SetModified
        @ret = true
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        @ret = DhcpServerUI.DhcpAutoSequence
      # Import configuration
      elsif @func == "Import"
        @ret = DhcpServer.Import(@param)
      # Return actual state
      elsif @func == "Export"
        @ret = KillComments(DhcpServer.Export)
      # Return needed packages
      elsif @func == "Packages"
        @ret = DhcpServer.AutoPackages
      # Read current state
      elsif @func == "Read"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = DhcpServer.Read
        Progress.set(@progress_orig)
      # Write givven settings
      elsif @func == "Write"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        DhcpServer.SetWriteOnly(true)
        @ret = DhcpServer.Write
        Progress.set(@progress_orig)
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("DhcpServer auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end

    # Remove all comments from export map
    # @param [Hash] exported map export map
    # @return [Hash] exported map without comments
    def KillComments(exported)
      exported = deep_copy(exported)
      settings = Ops.get_list(exported, "settings", [])
      settings = Builtins.maplist(
        Convert.convert(settings, :from => "list", :to => "list <map>")
      ) do |decl|
        if Builtins.haskey(decl, "comment_before")
          decl = Builtins.remove(decl, "comment_before")
        end
        if Builtins.haskey(decl, "comment_after")
          decl = Builtins.remove(decl, "comment_after")
        end
        if Builtins.haskey(decl, "options")
          options = Ops.get_list(decl, "options", [])
          options = Builtins.maplist(options) do |m|
            if Builtins.haskey(m, "comment_before")
              m = Builtins.remove(m, "comment_before")
            end
            if Builtins.haskey(m, "comment_after")
              m = Builtins.remove(m, "comment_after")
            end
            deep_copy(m)
          end
          Ops.set(decl, "options", options)
        end
        if Builtins.haskey(decl, "directives")
          directives = Ops.get_list(decl, "directives", [])
          directives = Builtins.maplist(directives) do |m|
            if Builtins.haskey(m, "comment_before")
              m = Builtins.remove(m, "comment_before")
            end
            if Builtins.haskey(m, "comment_after")
              m = Builtins.remove(m, "comment_after")
            end
            deep_copy(m)
          end
          Ops.set(decl, "directives", directives)
        end
        deep_copy(decl)
      end
      Ops.set(exported, "settings", settings)
      deep_copy(exported)
    end
  end
end

Yast::DhcpServerAutoClient.new.main
