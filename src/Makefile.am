# Sources for dhcp-server

module_DATA = \
  modules/DhcpServerUI.rb \
  modules/DhcpServer.pm

module1dir = @moduledir@/YaPI
module1_DATA = \
  modules/YaPI/DHCPD.pm

client_DATA = \
  clients/dhcp-server.rb \
  clients/dhcp-server_auto.rb

yncludedir = @yncludedir@/dhcp-server
ynclude_DATA = \
  include/dhcp-server/widgets.rb \
  include/dhcp-server/wizards.rb \
  include/dhcp-server/options.rb \
  include/dhcp-server/dns-server-dialogs.rb \
  include/dhcp-server/commandline.rb \
  include/dhcp-server/misc.rb \
  include/dhcp-server/dns-helps.rb \
  include/dhcp-server/dialogs2.rb \
  include/dhcp-server/dialogs.rb \
  include/dhcp-server/dns-server-management.rb \
  include/dhcp-server/dns-server-wizard.rb \
  include/dhcp-server/routines.rb \
  include/dhcp-server/helps.rb

scrconf_DATA = \
  scrconf/etc_dhcpd_conf.scr \
  scrconf/cfg_dhcpd.scr

agent_SCRIPTS = \
  servers_non_y2/ag_dhcpd_conf

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/dhcp-server.rnc

desktop_DATA = \
  desktop/org.opensuse.yast.DHCPServer.desktop

symbolicdir = @icondir@/hicolor/symbolic/apps
symbolic_DATA = \
  icons/hicolor/symbolic/apps/yast-dhcp-server-symbolic.svg
scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA = \
  icons/hicolor/scalable/apps/yast-dhcp-server.svg

EXTRA_DIST = $(module_DATA) $(module1_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(schemafiles_DATA) $(desktop_DATA) $(symbolic_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
