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

require "shellwords"

module Yast
  module DhcpServerWizardsInclude
    def initialize_dhcp_server_wizards(include_target)
      textdomain "dhcp-server"

      Yast.import "Directory"
      Yast.import "Wizard"
      Yast.import "Sequencer"
    end

    def FirstRunSequence
      aliases = {
        "cardselection"  => lambda { FirstRunDialog("card_selection", 1) },
        "globalsettings" => lambda { FirstRunDialog("global_settings", 2) },
        "dynamicdhcp"    => lambda { FirstRunDialog("dynamic_dhcp", 3) },
        "inst_summary"   => lambda { FirstRunDialog("inst_summary", 4) }
      }

      sequence = {
        "ws_start"       => "cardselection",
        "cardselection"  => { :abort => :abort, :next => "globalsettings" },
        "globalsettings" => { :abort => :abort, :next => "dynamicdhcp" },
        "dynamicdhcp"    => { :abort => :abort, :next => "inst_summary" },
        "inst_summary"   => { :abort => :abort, :next => :next, :main => :main }
      }

      ret = Sequencer.Run(aliases, sequence)

      deep_copy(ret)
    end

    # Run wizard sequencer
    # @return `next, `back or `abort
    def MainSequence
      aliases = {
        "configtype_switch"   => [lambda { ConfigTypeSwitch() }, true],
        "commonsetup"         => lambda { CommonConfigDialog() },
        "ifaces_switch"       => [lambda { CheckConfiguredInterfaces() }, true],
        "main"                => lambda { OldMainDialog() },
        "globals"             => lambda { GlobalsDialog() },
        "subnet"              => lambda { SubnetDialog() },
        "host"                => lambda { HostDialog() },
        "shared-network"      => lambda { SharedNetworkDialog() },
        "pool"                => lambda { PoolDialog() },
        "group"               => lambda { Groupdialog() },
        "class"               => lambda { ClassDialog() },
        "section_type_choose" => lambda { SectionTypeChoose() },
        "interfaces"          => lambda { IfacesDialog(false) },
        "interfaces_initial"  => lambda { IfacesDialog(true) },
        "dyn_dns"             => lambda { DynDnsDialog() },
        "section_type_select" => [lambda { SelectEditationDialog() }, true],
        "store"               => [lambda { SectionStore() }, true],
        "tsig_keys"           => lambda { RunTsigKeysDialog(false) },
        "tsig_keys_1"         => lambda { RunTsigKeysDialog(true) }
      }

      sequence = {
        "ws_start"            => "configtype_switch",
        "configtype_switch"   => { :simple => "commonsetup", :expert => "main" },
        "commonsetup"         => {
          :abort  => :abort,
          :next   => :next,
          :cancel => :cancel,
          :expert => "ifaces_switch"
        },
        "ifaces_switch"       => {
          :main   => "main",
          :ifaces => "interfaces_initial"
        },
        "interfaces_initial"  => { :abort => :abort, :next => "main" },
        "main"                => {
          :next       => :next,
          :abort      => :abort,
          :edit       => "section_type_select",
          :add        => "section_type_choose",
          :interfaces => "interfaces",
          :tsig_keys  => "tsig_keys"
        },
        "tsig_keys"           => { :next => "main", :abort => :abort },
        "section_type_choose" => {
          :abort => :abort,
          :next  => "section_type_select"
        },
        "section_type_select" => {
          :abort          => :abort,
          :global         => "globals",
          :subnet         => "subnet",
          :host           => "host",
          :group          => "group",
          :pool           => "pool",
          :shared_network => "shared-network",
          :class          => "class"
        },
        "globals"             => { :next => "store", :abort => :abort },
        "subnet"              => {
          :next      => "store",
          :abort     => :abort,
          :dyn_dns   => "dyn_dns",
          :tsig_keys => "tsig_keys_1"
        },
        "host"                => { :next => "store", :abort => :abort },
        "group"               => { :next => "store", :abort => :abort },
        "pool"                => { :next => "store", :abort => :abort },
        "shared-network"      => { :next => "store", :abort => :abort },
        "class"               => { :next => "store", :abort => :abort },
        "store"               => { :abort => :abort, :next => "main" },
        "interfaces"          => { :abort => :abort, :next => "main" },
        "dyn_dns"             => {
          :abort     => :abort,
          :next      => "subnet",
          :tsig_keys => "tsig_keys_1"
        },
        "tsig_keys_1"         => {
          :abort  => :abort,
          :next   => "dyn_dns",
          :subnet => "subnet"
        }
      }

      # run wizard sequencer
      Sequencer.Run(aliases, sequence)
    end

    # Whole configuration of dns-server in AI mode
    # @return sequence result
    def DhcpAutoSequence
      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("org.opensuse.yast.DHCPServer")
      Wizard.SetContentsButtons(
        "",
        VBox(),
        "",
        Label.BackButton,
        Label.NextButton
      )
      ret = MainSequence()
      UI.CloseDialog
      ret
    end

    # Whole configuration of dns-server
    # @return sequence result
    def DhcpSequence
      aliases = {
        "read"   => [lambda { ReadDialog() }, true],
        "wizard" => lambda { FirstRunSequence() },
        "main"   => lambda { MainSequence() },
        "write"  => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main", :wizard => "wizard" },
        "main"     => { :abort => :abort, :next => "write" },
        "wizard"   => { :abort => :abort, :next => "write", :main => "main" },
        "write"    => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("org.opensuse.yast.DHCPServer")
      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog

      if ret == :next
        SCR.Execute(
          path(".target.bash"),
          "/usr/bin/touch #{File.join(Directory.vardir, "dhcp_server_done_once").shellescape}"
        )
      end

      ret
    end
  end
end
