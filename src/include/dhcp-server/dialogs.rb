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
  module DhcpServerDialogsInclude
    def initialize_dhcp_server_dialogs(include_target)
      textdomain "dhcp-server"

      Yast.import "Wizard"
      Yast.import "DhcpServer"
      Yast.import "DhcpServerUI"
      Yast.import "CWM"

      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "Confirm"

      @functions = { :abort => fun_ref(method(:confirmAbort), "boolean ()") }
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Builtins.y2milestone("Running read dialog")
      Wizard.RestoreHelp(Ops.get(@HELPS, "read", ""))

      # checking for root permissions
      return :abort if !Confirm.MustBeRoot

      ret = DhcpServer.Read
      return DhcpServer.WasConfigured ? :next : :wizard if ret
      :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      Builtins.y2milestone("Running write dialog")
      Wizard.RestoreHelp(Ops.get(@HELPS, "write", ""))
      ret = DhcpServer.Write
      if ret && restart_after_writing?
        # Restart only if it's already running
        DhcpServerUI.service.try_restart
      end
      # yes-no popup
      if !ret &&
          Popup.YesNo(
            _("Saving the configuration failed. Change the settings?")
          )
        return :back
      end
      ret ? :next : :abort
    end

    # Write settings without quitting
    def SaveAndRestart(event)
      return nil unless CWM.validate_current_widgets(event)
      CWM.save_current_widgets(event)

      Wizard.CreateDialog
      Wizard.RestoreHelp(Ops.get(@HELPS, "write", ""))
      ret = DhcpServer.Write
      if ret
        # Restart only if it's already running
        DhcpServerUI.service.try_restart if restart_after_writing?
      else
        Report.Error(_("Saving the configuration failed"))
      end
      UI.CloseDialog

      nil
    end

    # Run main dialog
    # @return [Symbol] for wizard sequencer
    def OldMainDialog
      Builtins.y2milestone("Running main dialog")
      w = CWM.CreateWidgets(
        [
          "service_status", "chroot", "ldap_support",
          "configtree", "advanced", "apply"
        ],
        @widgets
      )
      contents = VBox(
        HBox(
          HSpacing(2),
          VBox(
            VSpacing(1),
            Left(Ops.get_term(w, [0, "widget"]) { VSpacing(0) }),
            VSpacing(1),
            Left(Ops.get_term(w, [1, "widget"]) { VSpacing(0) }),
            VSpacing(1),
            Left(Ops.get_term(w, [2, "widget"]) { VSpacing(0) }),
            VSpacing(1),
            Ops.get_term(w, [3, "widget"]) { VSpacing(0) }
          ),
          HSpacing(2)
        ),
        VSpacing(1),
        Right(
          HBox(
            w[4]["widget"],
            w[5]["widget"]
          )
        )
      )
      # dialog caption
      caption = _("DHCP Server Configuration")
      help = CWM.MergeHelps(w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.FinishButton
      )
      Wizard.HideBackButton
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      CWM.Run(
        w,
        { :abort => fun_ref(method(:confirmAbortIfChanged), "boolean ()") }
      )
    end

    # Run dialog for global options
    # @return [Symbol] for wizard sequencer
    def GlobalsDialog
      Builtins.y2milestone("Running global options dialog")
      w = CWM.CreateWidgets(["global_table"], @widgets)
      contents = HBox(
        HSpacing(2),
        VBox(VSpacing(1), Ops.get_term(w, [0, "widget"]) { VSpacing(0) }, VSpacing(
          1
        )),
        HSpacing(2)
      )
      # dialog caption
      caption = _("Global Options")
      help = CWM.MergeHelps(w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.RestoreAbortButton

      CWM.Run(w, @functions)
    end

    # Run subnet dialog
    # @return [Symbol] for wizard sequencer
    def SubnetDialog
      Builtins.y2milestone("Running subnet dialog")
      w = CWM.CreateWidgets(
        ["subnet", "subnet_table", "dyn_dns_button"],
        @widgets
      )
      contents = HBox(
        HSpacing(2),
        VBox(
          VSpacing(1),
          Ops.get_term(w, [0, "widget"]) { VSpacing(0) },
          VSpacing(1),
          Ops.get_term(w, [1, "widget"]) { VSpacing(0) },
          VSpacing(1)
        ),
        HSpacing(2)
      )
      # dialog caption
      caption = _("Subnet Configuration")
      help = CWM.MergeHelps(w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.RestoreAbortButton

      CWM.Run(w, @functions)
    end

    # Run host dialog
    # @return [Symbol] for wizard sequencer
    def HostDialog
      Builtins.y2milestone("Running host dialog")
      w = CWM.CreateWidgets(["host", "host_table"], @widgets)
      contents = HBox(
        HSpacing(2),
        VBox(
          VSpacing(1),
          HBox(HSpacing(2), Ops.get_term(w, [0, "widget"]) { VSpacing(0) }, HSpacing(
            2
          )),
          VSpacing(1),
          Ops.get_term(w, [1, "widget"]) { VSpacing(0) },
          VSpacing(1)
        ),
        HSpacing(2)
      )
      # dialog caption
      caption = _("Host with Fixed Address")
      help = CWM.MergeHelps(w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.RestoreAbortButton

      CWM.Run(w, @functions)
    end

    # Run shared network dialog
    # @return [Symbol] for wizard sequencer
    def SharedNetworkDialog
      Builtins.y2milestone("Running shared network dialog")
      w = CWM.CreateWidgets(
        ["shared-network", "shared-network_table"],
        @widgets
      )
      contents = HBox(
        HSpacing(2),
        VBox(
          VSpacing(1),
          HBox(HSpacing(2), Ops.get_term(w, [0, "widget"]) { VSpacing(0) }, HSpacing(
            2
          )),
          VSpacing(1),
          Ops.get_term(w, [1, "widget"]) { VSpacing(0) },
          VSpacing(1)
        ),
        HSpacing(2)
      )
      # dialog caption
      caption = _("Shared Network")
      help = CWM.MergeHelps(w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.RestoreAbortButton

      CWM.Run(w, @functions)
    end

    # Run address pool dialog
    # @return [Symbol] for wizard sequencer
    def PoolDialog
      Builtins.y2milestone("Running pool dialog")
      w = CWM.CreateWidgets(["pool", "pool_table"], @widgets)
      contents = HBox(
        HSpacing(2),
        VBox(
          VSpacing(1),
          HBox(HSpacing(2), Ops.get_term(w, [0, "widget"]) { VSpacing(0) }, HSpacing(
            2
          )),
          VSpacing(1),
          Ops.get_term(w, [1, "widget"]) { VSpacing(0) },
          VSpacing(1)
        ),
        HSpacing(2)
      )
      # dialog caption
      caption = _("Pool of Addresses")
      help = CWM.MergeHelps(w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.RestoreAbortButton

      return CWM.Run(w, @functions)
    end

    # Run group dialog
    # @return [Symbol] for wizard sequencer
    def Groupdialog
      Builtins.y2milestone("Running group dialog")
      w = CWM.CreateWidgets(["group", "group_table"], @widgets)
      contents = HBox(
        HSpacing(2),
        VBox(
          VSpacing(1),
          HBox(HSpacing(2), Ops.get_term(w, [0, "widget"]) { VSpacing(0) }, HSpacing(
            2
          )),
          VSpacing(1),
          Ops.get_term(w, [1, "widget"]) { VSpacing(0) },
          VSpacing(1)
        ),
        HSpacing(2)
      )
      # dialog caption
      caption = _("Group-Specific Options")
      help = CWM.MergeHelps(w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.RestoreAbortButton

      CWM.Run(w, @functions)
    end

    # Run class dialog
    # @return [Symbol] for wizard sequencer
    def ClassDialog
      Builtins.y2milestone("Running class dialog")
      w = CWM.CreateWidgets(["class", "class_table"], @widgets)
      contents = HBox(
        HSpacing(2),
        VBox(
          VSpacing(1),
          HBox(HSpacing(2), Ops.get_term(w, [0, "widget"]) { VSpacing(0) }, HSpacing(
            2
          )),
          VSpacing(1),
          Ops.get_term(w, [1, "widget"]) { VSpacing(0) },
          VSpacing(1)
        ),
        HSpacing(2)
      )
      # dialog caption
      caption = _("Class")
      help = CWM.MergeHelps(w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.RestoreAbortButton

      return CWM.Run(w, @functions)
    end

    # Run shared network dialog
    # @return [Symbol] for wizard sequencer
    def SectionTypeChoose
      Builtins.y2milestone("Running section type selection dialog")
      parents = []
      par_id = @parent_id
      par_type = @parent_type
      while par_id != ""
        parents << par_type

        par = DhcpServer.GetEntryParent(par_type, par_id)
        par_type = Ops.get(par, "type", "")
        par_id = Ops.get(par, "id", "")
      end
      possible = ["subnet", "host", "shared-network", "group", "pool", "class"]
      if ["class", "host", "pool"].include?(parents)
        return :back
      end
      filtered = ["pool"]
      if parents.include?("subnet")
        filtered.delete("pool")
        filtered << "subnet"
        filtered << "shared-network"
        filtered << "shared-network"
      end
      if parents.include?("shared-network")
        filtered << "shared-network"
      end
      possible -= filtered
      return :back if possible == []

      labels = {
        # radio button
        "subnet"         => _("&Subnet"),
        # radio button
        "host"           => _("&Host"),
        # radio button
        "shared-network" => _("Shared &Network"),
        # radio button
        "group"          => _("&Group"),
        # radio button
        "pool"           => _("&Pool of Addresses"),
        # radio button
        "class"          => _("&Class")
      }

      contents = VBox()
      Builtins.foreach(possible) do |p|
        contents = Builtins.add(contents, VSpacing(1))
        contents = Builtins.add(
          contents,
          Left(RadioButton(Id(p), Ops.get_string(labels, p, p)))
        )
      end
      contents = Builtins.add(contents, VSpacing(1))
      contents = HBox(HSpacing(5), contents, HSpacing(5))
      contents = RadioButtonGroup(Id(:entry_type), contents)
      # frame
      contents = Frame(_("Declaration Types"), contents)
      contents = HBox(
        HStretch(),
        VBox(VStretch(), contents, VStretch()),
        HStretch()
      )

      # dialog caption
      caption = _("Declaration Type")
      help = getSelectDeclarationTypeHelp(possible)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.NextButton
      )
      Wizard.RestoreAbortButton
      UI.ChangeWidget(Id(Ops.get(possible, 0)), :Value, true)

      ret = nil
      while ret == nil
        ret = Convert.to_symbol(UI.UserInput)
        ret = :abort if ret == :cancel
        ret = nil if ret == :abort && !confirmAbort
        ret = nil if ret != :next && ret != :abort && ret != :back
      end
      if ret == :next
        @current_entry_type = Convert.to_string(
          UI.QueryWidget(Id(:entry_type), :CurrentButton)
        )
      end
      ret
    end

    # Run interfaces and firewall dialog
    # @param [Boolean] initial boolean true if running before main dialog
    # @return [Symbol] for wizard sequencer
    def IfacesDialog(initial)
      Builtins.y2milestone("Running interfaces dialog")
      w = CWM.CreateWidgets(["interfaces", "open_firewall"], @widgets)
      contents = HBox(
        HStretch(),
        VBox(
          VStretch(),
          Ops.get_term(w, [0, "widget"]) { VSpacing(0) },
          VSpacing(3),
          Left(Ops.get_term(w, [1, "widget"]) { VSpacing(0) }),
          VStretch()
        ),
        HStretch()
      )
      # dialog caption
      caption = _("Interface Configuration")
      help = CWM.MergeHelps(w)
      next_label = initial ? Label.NextButton : Label.OKButton

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        next_label
      )
      if initial
        Wizard.HideBackButton
        Wizard.SetAbortButton(:abort, Label.CancelButton)
      else
        Wizard.RestoreAbortButton
        Wizard.RestoreBackButton
      end

      CWM.Run(w, @functions)
    end

    # Run Dynamic DNS dialog
    # @return [Symbol] for wizard sequencer
    def DynDnsDialog
      Builtins.y2milestone("Running interfaces dialog")
      w = ["ddns_enable", "zone", "zone_ip", "reverse_zone", "reverse_ip"]
      contents = HBox(
        HStretch(),
        VBox(
          VStretch(),
          Left("ddns_enable"),
          VSpacing(2),
          HBox("zone", "zone_ip"),
          HBox("reverse_zone", "reverse_ip"),
          VStretch()
        ),
        HStretch()
      )
      # dialog caption
      caption = _("Interface Configuration")

      CWM.ShowAndRun(
        {
          "widget_names"       => w,
          "widget_descr"       => @widgets,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => @functions
        }
      )
    end

    # Run TSIG keys management dialog
    # @return [Symbol] for wizard sequencer
    def RunTsigKeysDialog(called_from_subnet)
      Builtins.y2milestone("Running TSIG keys management dialog")

      w = ["tsig_keys"]

      contents = HBox(
        HSpacing(2),
        VBox(VSpacing(1), "tsig_keys", VSpacing(1)),
        HSpacing(2)
      )

      # dialog caption
      caption = _("TSIG Key Management")

      ret = CWM.ShowAndRun(
        {
          "widget_names"       => w,
          "widget_descr"       => @widgets,
          "contents"           => contents,
          "caption"            => caption,
          "back_button"        => Label.BackButton,
          "next_button"        => Label.OKButton,
          "fallback_functions" => {
            :abort => fun_ref(method(:confirmAbort), "boolean ()")
          }
        }
      )

      if ret == :next && called_from_subnet
        return :subnet if Builtins.size(DhcpServer.ListTSIGKeys) == 0
      end
      ret
    end

    # fake dialogs - switchers

    # detect the type of edited declaration
    # @return [Symbol] for ws
    def SelectEditationDialog
      Builtins.y2milestone("Determining what is selected")
      return :global if @current_entry_type == ""
      return :subnet if @current_entry_type == "subnet"
      return :host if @current_entry_type == "host"
      return :pool if @current_entry_type == "pool"
      return :group if @current_entry_type == "group"
      return :shared_network if @current_entry_type == "shared-network"
      return :class if @current_entry_type == "class"
      Builtins.y2error("Unknown declaration was selected")
      :back
    end

    # Store a section (declaration)
    # @return [Symbol] for ws, always `next
    def SectionStore
      if @current_operation == :edit # existing entry was edited
        Builtins.y2milestone("Storing changed record")
        DhcpServer.ChangeEntry(
          @original_entry_type,
          @original_entry_id,
          @current_entry_type,
          @current_entry_id
        ) # new entry was added
      else
        Builtins.y2milestone("Storing new record")
        DhcpServer.CreateEntry(
          @current_entry_type,
          @current_entry_id,
          @parent_type,
          @parent_id
        )
      end

      DhcpServer.SetEntryDirectives(
        @current_entry_type,
        @current_entry_id,
        @current_entry_directives
      )
      DhcpServer.SetEntryOptions(
        @current_entry_type,
        @current_entry_id,
        @current_entry_options
      )
      DhcpServer.SetModified

      # DhcpServer::SetDDNSFileName (current_ddns_key_file);
      #     DhcpServer::SetDDNSFileCreate (current_ddns_key_create);

      :next
    end

    # Detect if at least one network interface is selected
    # @return [Symbol] for wizard sequencer
    def CheckConfiguredInterfaces
      ifaces_allowed = DhcpServer.GetAllowedInterfaces
      return :ifaces if Builtins.size(ifaces_allowed) == 0
      :main
    end

    # Detect if simple configuration dialogs should be started
    # @return [Symbol] for wizard sequencer
    def ConfigTypeSwitch
      return :expert if Mode.config
      DhcpServer.IsConfigurationSimple ? :simple : :expert
    end
  end
end
