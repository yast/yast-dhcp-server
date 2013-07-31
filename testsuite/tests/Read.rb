# encoding: utf-8

# File:
#  rw.ycp
#
# Module:
#  DHCP server configurator
#
# Summary:
#  Read and write testsuite
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  class ReadClient < Client
    def main
      Yast.include self, "testsuite.rb"

      # testedfiles: DhcpServer.pm

      TESTSUITE_INIT([], nil)
      Yast.import "Progress"
      Yast.import "DhcpServer"
      Yast.import "Mode"

      Mode.SetTest("testsuite")

      @progress_orig = Progress.set(false)

      @READ = {
        # Runlevel
        "init"      => {
          "scripts" => {
            "exists"   => true,
            "runlevel" => { "dhcpd" => { "start" => [], "stop" => [] } }
          }
        },
        "etc"       => {
          "dhcpd_conf" => [
            {
              "comment_after"  => "",
              "comment_before" => "# dhcpd.conf",
              "key"            => "domain-name",
              "type"           => "option",
              "value"          => "\"example.org\""
            },
            {
              "comment_after"  => "",
              "comment_before" => "",
              "key"            => "domain-name-servers",
              "type"           => "option",
              "value"          => "ns1.example.org, ns2.example.org"
            },
            {
              "comment_after"  => "",
              "comment_before" => "",
              "key"            => "policy-filter",
              "type"           => "option",
              "value"          => "{ a1, a2 }, { a1, a2 }, { a3, a4 }"
            }
          ]
        },
        "target"    => { "stat" => {}, "size" => 5 },
        "sysconfig" => {
          "dhcpd" => {
            "DHCPD_INTERFACE"    => "eth0 eth2",
            "DHCPD_RUN_CHROOTED" => "no",
            "DHCPD_OTHER_ARGS"   => "-p 111"
          }
        },
        "product"   => {
          "features" => {
            "USE_DESKTOP_SCHEDULER"           => "0",
            "ENABLE_AUTOLOGIN"                => "0",
            "EVMS_CONFIG"                     => "0",
            "IO_SCHEDULER"                    => "cfg",
            "UI_MODE"                         => "expert",
            "INCOMPLETE_TRANSLATION_TRESHOLD" => "95"
          }
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

      TEST(lambda { DhcpServer.Read }, [@READ, @WRITE, @EXEC], 0)
      TEST(lambda { DhcpServer.Export }, [], 0)

      nil
    end
  end
end

Yast::ReadClient.new.main
