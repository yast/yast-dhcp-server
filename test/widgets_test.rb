require_relative "test_helper"

Yast.import "UI"

module Yast
  class Test < Yast::Client
    def initialize
      Yast.include self, "dhcp-server/widgets.rb"
      @ifaces = {"eth0" => {"active" => true}}
    end
  end
end

describe "Yast::DhcpServerWidgetsInclude" do
  subject { Yast::Test.new }

  describe "#DNSZonesValidate" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(Id("ddns_enable"), :Value)
        .and_return(true)

      allow(Yast::UI).to receive(:QueryWidget).with(Id("zone_ip"), :Value)
        .and_return("127.0.0.1")
      allow(Yast::UI).to receive(:QueryWidget).with(Id("reverse_ip"), :Value)
        .and_return("127.0.0.1")
      allow(Yast::UI).to receive(:QueryWidget).with(Id("zone"), :Value)
        .and_return("test.suse.cz")
      allow(Yast::UI).to receive(:QueryWidget).with(Id("reverse_zone"), :Value)
        .and_return("test2.suse.cz")
    end

    it "returns true if dynanic dns is not enabled" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id("ddns_enable"), :Value)
        .and_return(false)
      # add one failing to test that it do not fail
      allow(Yast::UI).to receive(:QueryWidget).with(Id("zone_ip"), :Value)
        .and_return("666.666.666.666")

      expect(subject.DNSZonesValidate("ddns_enable", {})).to eq true
    end

    it "returns false and report error if zone_ip is invalid IPv4" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id("zone_ip"), :Value)
        .and_return("666.666.666.666")
      expect(Yast::Report).to receive(:Error)

      expect(subject.DNSZonesValidate("ddns_enable", {})).to eq false
    end

    it "returns false and report error if zone is not FQDN" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id("zone"), :Value)
        .and_return("bla***bla")
      expect(Yast::Report).to receive(:Error)

      expect(subject.DNSZonesValidate("ddns_enable", {})).to eq false
    end

    it "returns true even if zone contains trailing comma" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id("zone"), :Value)
        .and_return("test.suse.cz.")

      expect(subject.DNSZonesValidate("ddns_enable", {})).to eq true
    end

    it "returns true if zone_ip is empty" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id("zone_ip"), :Value)
        .and_return("")

      expect(subject.DNSZonesValidate("ddns_enable", {})).to eq true
    end
  end

  describe "#OpenFirewallValidate" do
    context "firewall not enabled" do
      it "returns true" do
        expect(Y2Firewall::Firewalld.instance).to receive(:enabled?).and_return(false)
        expect(Yast::Popup).not_to receive(:YesNo)
        expect(Yast::Report).not_to receive(:Error)
        expect(subject.OpenFirewallValidate("widget_id",0)).to eq true
      end
    end

    context "firewall enabled" do
      before do
        allow(Y2Firewall::Firewalld.instance).to receive(:enabled?).and_return(true)
      end

      context "port is not opened" do
        before do
          allow(Yast::Report).to receive(:Error)
          allow(Yast::UI).to receive(:QueryWidget).with(Id("open_port"), :Value)
            .and_return(false)
        end

        it "asks for continuing" do
          expect(Yast::Popup).to receive(:YesNo).and_return(true)
          expect(subject.OpenFirewallValidate("open_port",0)).to eq true
        end
      end

      context "port is opened" do
        before do
          allow(Yast::UI).to receive(:QueryWidget).with(Id("open_port"), :Value)
            .and_return(true)
        end

        it "reports interfaces which are not mentioned in any firewall zone" do
          expect(Y2Firewall::Firewalld.instance).to receive(:zones).and_return([])
          expect(Yast::Report).to receive(:Error)
          expect(subject.OpenFirewallValidate("open_port",0)).to eq true
        end
      end
    end
  end
end
