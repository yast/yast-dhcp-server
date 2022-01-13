#!/usr/bin/env rspec

# Copyright (c) [2022] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

Yast.import "DnsServerAPI"

describe "DhcpServerDnsServerDialogsInclude" do
  subject(:dialog) { TestDNSDialog.new }

  class TestDNSDialog
    include Yast::I18n

    def initialize
      Yast.include self, "dhcp-server/dns-server-dialogs.rb"
    end
  end

  describe "#IsDNSZoneMaintained" do
    before do
      allow(Yast::DnsServerAPI).to receive(:GetZones).and_return(zones)
    end

    let(:zones) do
      {
        "example.org" => { "type" => "master" },
        "forward.org" => { "type" => "forward" }
      }
    end

    context "when a zone name is not given" do
      it "returns nil" do
        expect(dialog.IsDNSZoneMaintained(nil)).to be_nil
      end
    end

    context "when a zone name is given" do
      context "and it is included in maintained zones" do
        it "returns true" do
          expect(dialog.IsDNSZoneMaintained("example.org")).to eq(true)
        end
      end

      context "but it is NOT included in maintained zones" do
        it "returns false" do
          expect(dialog.IsDNSZoneMaintained("not-maintained-zone.org")).to eq(false)
        end
      end
    end
  end
end
