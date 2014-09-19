#!/usr/bin/env rspec

require 'rspec'
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)
require "yast"

module Yast
  import "YaPI::DHCPD"
  import "Service"

  describe YaPI::DHCPD do
    describe ".StartDhcpService" do
      let(:result) { YaPI::DHCPD.StartDhcpService({}) }

      it "delegates to Service.Restart and reports success back" do
        expect(Service).to receive(:Restart).with("dhcpd").and_return true
        expect(result).to eql(true)
      end

      it "delegates to Service.Restart and reports failure back" do
        expect(Service).to receive(:Restart).with("dhcpd").and_return false
        expect(result).to eql(false)
      end
    end

    describe ".StopDhcpService" do
      let(:result) { YaPI::DHCPD.StopDhcpService({}) }

      it "delegates to Service.Stop and reports success back" do
        expect(Service).to receive(:Stop).with("dhcpd").and_return true
        expect(result).to eql(true)
      end

      it "delegates to Service.Stop and reports failure back" do
        expect(Service).to receive(:Stop).with("dhcpd").and_return false
        expect(result).to eql(false)
      end
    end

    describe ".GetDhcpServiceStatus" do
      let(:result) { YaPI::DHCPD.GetDhcpServiceStatus({}) }

      it "delegates to Service.Active and properly reports a running system" do
        expect(Service).to receive(:Active).with("dhcpd").and_return true
        expect(result).to eql(true)
      end

      it "delegates to Service.Active and properly reports a stopped system" do
        expect(Service).to receive(:Active).with("dhcpd").and_return false
        expect(result).to eql(false)
      end
    end
  end
end
