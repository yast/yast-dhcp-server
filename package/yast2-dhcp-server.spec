#
# spec file for package yast2-dhcp-server
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-dhcp-server
Version:        4.0.2
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0
BuildRequires:	perl-Digest-SHA1 perl-X500-DN perl-XML-Writer docbook-xsl-stylesheets doxygen libxslt perl-XML-Writer popt-devel sgml-skel update-desktop-files yast2-perl-bindings yast2-testsuite yast2-dns-server
BuildRequires:  yast2-devtools >= 3.1.10
# Yast2::ServiceWidget
BuildRequires:  yast2 >= 4.1.0

Requires:       perl-gettext yast2-perl-bindings bind-utils perl-X500-DN yast2-ldap perl-Digest-SHA1 perl-Parse-RecDescent
# Yast2::ServiceWidget
Requires:       yast2 >= 4.1.0
# DnsServerAPI::IsServiceConfigurableExternally
Requires:       yast2-dns-server >= 2.13.16

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - DHCP Server Configuration

%description
This package contains the YaST2 component for DHCP server
configuration.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/dhcp-server
%{yast_yncludedir}/dhcp-server/*
%{yast_clientdir}/dhcp-server.rb
%{yast_clientdir}/dhcp-server_*.rb
%{yast_moduledir}/*
%{yast_desktopdir}/dhcp-server.desktop
%{yast_scrconfdir}/cfg_dhcpd.scr
%{yast_scrconfdir}/etc_dhcpd_conf.scr
%{yast_agentdir}/ag_dhcpd_conf
%doc %{yast_docdir}
%{yast_schemadir}/autoyast/rnc/dhcp-server.rnc

