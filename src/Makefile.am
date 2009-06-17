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
	options.ycp		\
	commandline.ycp		\
	misc.ycp		\
	dns-helps.ycp		\
	dns-server-wizard.ycp	\
	dns-server-dialogs.ycp	\
	dns-server-management.ycp

desktop_DATA =                  \
	dhcp-server.desktop

module_DATA =			\
	DhcpServerUI.ycp	\
	DhcpServer.pm

YaPI_perldir = @moduledir@/YaPI

YaPI_perl_DATA = \
	DHCPD.pm

rncdir= $(schemadir)/autoyast/rnc

rnc_DATA = \
	dhcp-server.rnc


EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA) $(YaPI_perl_DATA) $(rnc_DATA)

dhcp-server:
	test -L dhcp-server || ln -s . dhcp-server

ycpchook = dhcp-server

include $(top_srcdir)/Makefile.am.common

