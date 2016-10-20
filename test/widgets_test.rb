require_relative "test_helper"

Yast.import "UI"

module Yast
  class Test < Yast::Client
    def initialize
      Yast.include self, "dhcp-server/widgets.rb"
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
end
