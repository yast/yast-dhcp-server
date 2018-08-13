#!/usr/bin/env rspec
# encoding: utf-8
# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

require "yast2/system_service"
require "cwm/service_widget"

Yast.import "DhcpServer"

describe "DhcpServerDialogsInclude" do
    subject(:dialog) { TestDialog.new }

  class TestDialog
    include Yast::I18n
    include Yast::UIShortcuts

    def initialize
      @HELPS = {}
      Yast.include self, "dhcp-server/widgets.rb"
      Yast.include self, "dhcp-server/dialogs.rb"
    end

    def fun_ref(*args)
    end
  end

  let(:widget) { instance_double(::CWM::ServiceWidget, cwm_definition: {}) }
  let(:service) { instance_double(Yast2::SystemService, save: true, currently_active?: true) }

  before do
    allow(::CWM::ServiceWidget).to receive(:new).and_return(widget)
    allow(Yast2::SystemService).to receive(:find).with("dhcpd").and_return(service)
  end

  describe "#WriteDialog" do
    let(:dhcp_configuration_written) { true }

    before do
      allow(Yast::DhcpServer).to receive(:Write).and_return(dhcp_configuration_written)
    end

    it "writes needed configuration" do
      expect(Yast::DhcpServer).to receive(:Write)

      dialog.WriteDialog
    end

    context "when configuration is written" do
      it "saves the system service" do
        expect(service).to receive(:save)

        dialog.WriteDialog
      end

      it "returns :next" do
        expect(dialog.WriteDialog).to eq(:next)
      end

      context "and is in `auto` Mode" do
        before do 
          allow(Yast::Mode).to receive(:auto).and_return(true)
        end

        it "keeps current system status" do
          expect(service).to receive(:save).with(hash_including(keep_state: true))

          dialog.WriteDialog
        end
      end
    end

    context "when the configuration is not written" do
      before do
        allow(Yast2::Popup).to receive(:show).and_return(change_settings)
      end

      let(:change_settings) { :yes }
      let(:dhcp_configuration_written) { false }

      it "does not save the system service" do
        expect(service).to_not receive(:save)

        dialog.WriteDialog
      end

      it "asks for changing the current settings" do
        expect(Yast2::Popup).to receive(:show)
          .with(instance_of(String), hash_including(buttons: :yes_no))

        dialog.WriteDialog
      end

      context "and user decides to change the current setting" do
        it "returns :back" do
          expect(dialog.WriteDialog).to eq(:back)
        end
      end

      context "and user decides to cancel" do
        let(:change_settings) { :no }

        it "returns :abort" do
          expect(subject.WriteDialog).to eq(:abort)
        end
      end
    end
  end
end
