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
	dialogs.ycp		\
	dialogs2.ycp		\
	wizards.ycp		\
	routines.ycp		\
	widgets.ycp		\
	options.ycp

desktop_DATA =                  \
	dhcp-server.desktop

module_DATA =			\
	DhcpServerUI.ycp	\
	DhcpServer.pm		\
	DhcpTsigKeys.pm

YaPI_perldir = @moduledir@/YaPI

YaPI_perl_DATA = \
	DHCPD.pm


EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA) $(YaPI_perl_DATA)

dhcp-server:
	test -l dhcp-server || ln -s . dhcp-server

ycpchook = dhcp-server

include $(top_srcdir)/Makefile.am.common

