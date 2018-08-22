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
require "yast"
require "yast2/system_service"

module Yast
  class DhcpServerUIClass < Module
    def main
      Yast.import "UI"
      textdomain "dhcp-server"

      Yast.import "DhcpServer"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "SuSEFirewall"

      @current_entry_type = ""
      @current_entry_id = ""
      @current_entry_options = []
      @current_entry_directives = []
      @original_entry_type = ""
      @original_entry_id = ""
      @parent_type = ""
      @parent_id = ""
      @current_operation = nil

      @current_tsig_keys = []
      @new_tsig_keys = []
      @deleted_tsig_keys = []


      #    global string current_ddns_key_file = "";
      #  global boolean current_ddns_key_create = false;

      @widgets = {}

      @popups = {}

      # temporary variables
      @entry_list = []

      # Network interfaces
      @ifaces = {}


      Yast.include self, "dhcp-server/routines.rb"
      Yast.include self, "dhcp-server/helps.rb"
      Yast.include self, "dhcp-server/options.rb"
      Yast.include self, "dhcp-server/widgets.rb"
      Yast.include self, "dhcp-server/dialogs.rb"
      Yast.include self, "dhcp-server/dialogs2.rb"
      Yast.include self, "dhcp-server/wizards.rb"

      # Abort function
      # return boolean return true if abort
      @AbortFunction = nil
      DhcpServerUI()
    end

    # Constructor
    def DhcpServerUI
      InitPopups()
      InitWidgets()
      @widgets = Convert.convert(
        Builtins.union(@widgets, @new_widgets),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )

      nil
    end

    # Object representing the DHCP service for its usage in the UI code
    #
    # @return [Yast2::Systemd::Service]
    def service
      @service ||= Yast2::SystemService.find(DhcpServer.ServiceName())
    end

    publish :variable => :current_entry_type, :type => "string"
    publish :variable => :current_entry_id, :type => "string"
    publish :variable => :current_entry_options, :type => "list <map <string, string>>"
    publish :variable => :current_entry_directives, :type => "list <map <string, string>>"
    publish :variable => :original_entry_type, :type => "string"
    publish :variable => :original_entry_id, :type => "string"
    publish :variable => :parent_type, :type => "string"
    publish :variable => :parent_id, :type => "string"
    publish :variable => :current_operation, :type => "symbol"
    publish :variable => :widgets, :type => "map <string, map <string, any>>"
    publish :variable => :popups, :type => "map"
    publish :variable => :ifaces, :type => "map <string, map <string, any>>"
    publish :function => :typeid2key, :type => "string (string, string)"
    publish :function => :key2typeid, :type => "map <string, string> (string)"
    publish :function => :getItems, :type => "list (string, string)"
    publish :function => :createNewSection, :type => "map (symbol)"
    publish :function => :fetchValue, :type => "any (any, string)"
    publish :function => :storeValue, :type => "void (any, string, any)"
    publish :function => :commonPopupInit, :type => "void (any, string)"
    publish :function => :commonPopupSave, :type => "void (any, string)"
    publish :function => :commonTableEntrySummary, :type => "string (any, string)"
    publish :function => :textWidgetInit, :type => "void (any, string)"
    publish :function => :quoted_string_init, :type => "void (any, string)"
    publish :function => :textWidgetStore, :type => "void (any, string)"
    publish :function => :ip_address_validate, :type => "boolean (any, string, map)"
    publish :function => :redraw_list, :type => "void (any, string, map, string)"
    publish :function => :init_list, :type => "void (any, string, string)"
    publish :function => :ip_array_init, :type => "void (any, string)"
    publish :function => :ip_array_handle, :type => "void (any, string, map)"
    publish :function => :ip_array_validate, :type => "boolean (any, string, map)"
    publish :function => :entry_array_store, :type => "void (any, string)"
    publish :function => :uint16_array_init, :type => "void (any, string)"
    publish :function => :uint16_array_handle, :type => "void (any, string, map)"
    publish :function => :value_array_validate, :type => "boolean (any, string, map)"
    publish :function => :ip_pair_array_handle, :type => "void (any, string, map)"
    publish :function => :ip_pair_array_validate, :type => "boolean (any, string, map)"
    publish :function => :flagInit, :type => "void (any, string)"
    publish :function => :flagStore, :type => "void (any, string)"
    publish :function => :flagSummary, :type => "string (any, string)"
    publish :function => :onoffInit, :type => "void (any, string)"
    publish :function => :onoffStore, :type => "void (any, string)"
    publish :function => :onoffSummary, :type => "string (any, string)"
    publish :function => :quoted_string_validate, :type => "boolean (any, string, map)"
    publish :function => :validate_value, :type => "boolean (any, string, map)"
    publish :function => :uint8_widget, :type => "map ()"
    publish :function => :uint16_widget, :type => "map ()"
    publish :function => :uint32_widget, :type => "map ()"
    publish :function => :int32_widget, :type => "map ()"
    publish :function => :text_widget, :type => "map ()"
    publish :function => :quoted_string_widget, :type => "map ()"
    publish :function => :ip_address_widget, :type => "map ()"
    publish :function => :array_ip_address_widget, :type => "map ()"
    publish :function => :array_uint16_widget, :type => "map ()"
    publish :function => :array_ip_address_pair_widget, :type => "map ()"
    publish :function => :hardwareInit, :type => "void (any, string)"
    publish :function => :hardwareStore, :type => "void (any, string)"
    publish :function => :hardwareValidate, :type => "boolean (any, string, map)"
    publish :function => :rangeInit, :type => "void (any, string)"
    publish :function => :rangeStore, :type => "void (any, string)"
    publish :function => :rangeValidate, :type => "boolean (any, string, map)"
    publish :function => :InitPopups, :type => "void ()"
    publish :function => :configTreeInit, :type => "void (string)"
    publish :function => :chrootHandle, :type => "symbol (string, map)"
    publish :function => :ldapHandle, :type => "symbol (string, map)"
    publish :function => :commonTableEntryDelete, :type => "boolean (any, string)"
    publish :function => :getTableContents, :type => "list (map)"
    publish :function => :id2key, :type => "string (map, any)"
    publish :function => :key2descr, :type => "map (string)"
    publish :function => :getOptionsTableWidget, :type => "map <string, any> (list)"
    publish :function => :confirmAbort, :type => "boolean ()"
    publish :function => :confirmAbortIfChanged, :type => "boolean ()"
    publish :function => :startInit, :type => "void (string)"
    publish :function => :startStore, :type => "void (string, map)"
    publish :function => :startHandle, :type => "symbol (string, map)"
    publish :function => :chrootInit, :type => "void (string)"
    publish :function => :chrootStore, :type => "void (string, map)"
    publish :function => :ldapInit, :type => "void (string)"
    publish :function => :SetUseLdap, :type => "void (boolean)"
    publish :function => :OpenFirewallInit, :type => "void (string)"
    publish :function => :OpenFirewallStore, :type => "void (string, map)"
    publish :function => :OpenFirewallValidate, :type => "boolean (string, map)"
    publish :function => :configTreeHandle, :type => "symbol (string, map)"
    publish :function => :subnetInit, :type => "void (string)"
    publish :function => :subnetStore, :type => "void (string, map)"
    publish :function => :idInit, :type => "void (string)"
    publish :function => :idStore, :type => "void (string, map)"
    publish :function => :interfacesInit, :type => "void (string)"
    publish :function => :interfacesStore, :type => "void (string, map)"
    publish :function => :DynDnsButtonInit, :type => "void (string)"
    publish :function => :DynDnsButtonHandle, :type => "symbol (string, map)"
    publish :function => :DDNSZonesHandle, :type => "symbol (string, map)"
    publish :function => :DDNSZonesInit, :type => "void (string)"
    publish :function => :DNSZonesValidate, :type => "boolean (string, map)"
    publish :function => :DDNSZonesStore, :type => "void (string, map)"
    publish :function => :KeyFileBrowseButtonHandle, :type => "symbol (string, map)"
    publish :function => :EmptyOrIpValidate, :type => "boolean (string, map)"
    publish :function => :InitWidgets, :type => "void ()"
    publish :variable => :functions, :type => "map <symbol, any>"
    publish :function => :ReadDialog, :type => "symbol ()"
    publish :function => :WriteDialog, :type => "symbol ()"
    publish :function => :OldMainDialog, :type => "symbol ()"
    publish :function => :GlobalsDialog, :type => "symbol ()"
    publish :function => :SubnetDialog, :type => "symbol ()"
    publish :function => :HostDialog, :type => "symbol ()"
    publish :function => :SharedNetworkDialog, :type => "symbol ()"
    publish :function => :PoolDialog, :type => "symbol ()"
    publish :function => :Groupdialog, :type => "symbol ()"
    publish :function => :ClassDialog, :type => "symbol ()"
    publish :function => :SectionTypeChoose, :type => "symbol ()"
    publish :function => :IfacesDialog, :type => "symbol (boolean)"
    publish :function => :DynDnsDialog, :type => "symbol ()"
    publish :function => :RunTsigKeysDialog, :type => "symbol (boolean)"
    publish :function => :SelectEditationDialog, :type => "symbol ()"
    publish :function => :SectionStore, :type => "symbol ()"
    publish :function => :CheckConfiguredInterfaces, :type => "symbol ()"
    publish :function => :ConfigTypeSwitch, :type => "symbol ()"
    publish :function => :MainSequence, :type => "symbol ()"
    publish :function => :DhcpAutoSequence, :type => "symbol ()"
    publish :function => :DhcpSequence, :type => "symbol ()"
    publish :variable => :AbortFunction, :type => "boolean ()"
    publish :function => :DhcpServerUI, :type => "void ()"
  end

  DhcpServerUI = DhcpServerUIClass.new
  DhcpServerUI.main
end
