#
# Makefile.am for devtools/devtools/skeletons/config/src
#

yncludedir = @yncludedir@/dhcp-server

YCPCFLAGS = -M . -I .

client_DATA =			\
	dhcp-server.ycp		\
	dhcp-server_auto.ycp

ynclude_DATA =			\
	helps.ycp		\
	ui.ycp			\
	routines.ycp		\
	widgets.ycp		\
	options.ycp


config_DATA =			\
	dhcp-server.y2cc

desktop_DATA =                  \
	dhcp-server.desktop

module_DATA =			\
	DhcpServerUI.ycp	\
	DhcpServer.pm

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(config_DATA) $(module_DATA) $(desktop_DATA)

dhcp-server:
	test -l dhcp-server || ln -s . dhcp-server

ycpchook = dhcp-server

include $(top_srcdir)/Makefile.am.common

