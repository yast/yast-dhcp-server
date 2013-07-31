# encoding: utf-8

module Yast
  class YaPIAddDeclarationClient < Client
    def main
      # testedfiles: DhcpServer.pm

      Yast.include self, "testsuite.rb"

      Yast.import "YaPI::DHCPD"
      Yast.import "Mode"

      Mode.SetTest("testsuite")

      @READ = {
        # Runlevel
        "init"      => {
          "scripts" => {
            "exists"   => true,
            "runlevel" => { "dhcpd" => { "start" => [], "stop" => [] } }
          }
        },
        "target"    => { "stat" => {}, "size" => 5 },
        "sysconfig" => {
          "dhcpd" => {
            "DHCPD_INTERFACE"    => "eth0 eth2",
            "DHCPD_RUN_CHROOTED" => "no",
            "DHCPD_OTHER_ARGS"   => "-p 111"
          }
        },
        "etc"       => {
          "dhcpd_conf" => [
            {
              "value" => "\"example.net\"",
              "type"  => "option",
              "key"   => "domain-name"
            },
            {
              "value" => "none",
              "type"  => "directive",
              "key"   => "ddns-update-style"
            },
            {
              "value" => [
                {
                  "value" => "192.168.0.100 192.168.0.200",
                  "type"  => "directive",
                  "key"   => "range"
                },
                {
                  "value" => [
                    {
                      "value" => "192.168.0.1",
                      "type"  => "directive",
                      "key"   => "fixed-address"
                    },
                    {
                      "value" => "ethernet 11:22:33:44:55:66",
                      "type"  => "directive",
                      "key"   => "hardware"
                    }
                  ],
                  "type"  => "host",
                  "key"   => "h1"
                },
                {
                  "value" => [
                    {
                      "value" => "192.168.0.2",
                      "type"  => "directive",
                      "key"   => "fixed-address"
                    },
                    {
                      "value" => "ethernet 11:22:33:44:55:77",
                      "type"  => "directive",
                      "key"   => "hardware"
                    }
                  ],
                  "type"  => "host",
                  "key"   => "h2"
                }
              ],
              "type"  => "subnet",
              "key"   => "192.168.0.0 netmask 255.255.255.0"
            }
          ]
        }
      }

      @WRITE = {}
      @EXEC = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "localhost",
            "stderr" => "localhost"
          },
          "bash"        => 1
        }
      }

      DUMP("==========================================================")
      TEST(lambda do
        YaPI::DHCPD.AddDeclaration(
          {},
          "subnet",
          "192.168.5.1 netmask 255.255.255.0",
          "",
          ""
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      DUMP("==========================================================")

      nil
    end
  end
end

Yast::YaPIAddDeclarationClient.new.main
