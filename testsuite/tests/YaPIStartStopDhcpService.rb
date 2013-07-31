# encoding: utf-8

module Yast
  class YaPIStartStopDhcpServiceClient < Client
    def main
      # testedfiles: DHCPD.pm

      Yast.include self, "testsuite.rb"

      Yast.import "YaPI::DHCPD"
      Yast.import "Mode"

      Mode.SetTest("testsuite")

      DUMP("==========================================================")
      TEST(lambda { YaPI::DHCPD.StartDhcpService({}) }, [], nil)
      DUMP("==========================================================")
      TEST(lambda { YaPI::DHCPD.StopDhcpService({}) }, [], nil)
      DUMP("==========================================================")
      TEST(lambda { YaPI::DHCPD.GetDhcpServiceStatus({}) }, [], nil)
      DUMP("==========================================================")

      nil
    end
  end
end

Yast::YaPIStartStopDhcpServiceClient.new.main
