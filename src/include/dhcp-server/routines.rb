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
  module DhcpServerRoutinesInclude
    def initialize_dhcp_server_routines(include_target)
      textdomain "dhcp-server"
    end

    # Merge section id and key together to one identifier
    # @param [String] type string section type
    # @param [String] id string section identifier
    # @return merged section type and id to one string
    def typeid2key(type, id)
      Builtins.sformat("%1 %2", type, id)
    end

    # Split section type and id to two separate strings
    # @param [String] key string section type and id merged into one string
    # @return a map with keys "type" and "id"
    def key2typeid(key)
      return { "type" => "", "id" => "" } if key == " "
      return nil if !Builtins.regexpmatch(key, "^[^ ]+ .+$")
      type = Builtins.regexpsub(key, "^([^ ]+) .+$", "\\1")
      id = Builtins.regexpsub(key, "^[^ ]+ (.+)$", "\\1")
      { "type" => type, "id" => id }
    end

    # Get children declarations of a declaration
    # @param [String] type strign declaration type
    # @param [String] id string declaration id
    # @return [Array] of items for the tree widget
    def getItems(type, id)
      entries = DhcpServer.GetChildrenOfEntry(type, id)
      return [] if entries == nil
      ret = Builtins.maplist(entries) do |e|
        type2 = Ops.get_string(e, "type", "group")
        id2 = Ops.get_string(e, "id", "")
        subentries = DhcpServer.GetChildrenOfEntry(type2, id2)
        full_id = typeid2key(type2, id2)
        if Ops.greater_than(Builtins.size(subentries), 0)
          next Item(Id(full_id), full_id, true, getItems(type2, id2))
        end
        Item(Id(full_id), full_id)
      end
      deep_copy(ret)
    end

    # Abort function
    # @return blah blah lahjk
    # global define boolean Abort() ``{
    #     if(AbortFunction != nil)
    # 	return eval(AbortFunction) == true;
    #     return false;
    # }

    # Create new section
    # @param @param what symbol specifying the section type, `global, `subnet
    #  or `host
    # @return [Hash] created section
    def createNewSection(what)
      if what == :global
        return {
          "default-lease-time" => 600,
          "max-lease-time"     => 7200,
          "ddns-update-style"  => "none",
          "ddns-updates"       => "off",
          "log-facility"       => "local7",
          "authoritative"      => ""
        }
      elsif what == :subnet
        return {
          "subnet"         => "",
          "netmask"        => "",
          "range"          => "",
          "option routers" => ""
        }
      elsif what == :host
        return { "host" => "", "hardware" => "", "fixed-address" => "" }
      end

      {}
    end
  end
end
