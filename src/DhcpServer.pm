#! /usr/bin/perl -w
#
# DnsServer module written in Perl
#

package DhcpServer;

use strict;

use ycp;
use YaST::YCP qw(Boolean);
use Data::Dumper;
use Time::localtime;

#use io_routines;
#use check_routines;

our %TYPEINFO;

# persistent variables

my $start_service = 0;

my $chroot = 0;

my @allowed_interfaces = ();

my @settings = ();

#transient variables

my $modified = 0;

my $adapt_firewall = 0;

my $write_only = 0;


# FIXME remove this func

sub _ {
    return $_[0];
}


YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Service");

##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

sub AdaptFirewall {
    if (! $adapt_firewall)
    {
	return 1;
    }
    foreach my $i ("INT", "EXT", "DMZ") {
	y2milestone ("Removing dhcpd iface $i");
	SuSEFirewall::RemoveService ("67", "UDP", $i);
    }
    if ($start_service)
    {
	foreach my $i (@allowed_interfaces) {
	    y2milestone ("Adding dhcpd iface %1", $i);
	    SuSEFirewall::AddService ("67", "UDP", $i);
	}
    }
    if (! Mode::test ())
    {
	Progress::off ();
	SuSEFirewall::Write ();
	Progress::on ();
    }
    if ($start_service)
    {
	SCR::Write (".sysconfig.SuSEfirewall2.FW_SERVICE_DHCPD",
	    SuSEFirewall::MostInsecureInterface (@allowed_interfaces));
    }
    else
    {
	SCR::Write (".sysconfig.SuSEfirewall2.FW_SERVICE_DHCPD", "no");
    }

    SCR::Write (".sysconfig.SuSEfirewall2", undef);
    if (! $write_only)
    {
	SCR::Execute (".target.bash", "test -x /sbin/rcSuSEfirewall2 && /sbin/rcSuSEfirewall2 status && /sbin/rcSuSEfirewall2 restart");
    }

}

sub PreprocessSettings {
    my $sect_ref = $_[0];
    my $header_ref = $_[1];

    my $parent_id = $header_ref->{"parent_id"} || "";
    my $parent_type = $header_ref->{"parent_type"} || "";
    my $id = $header_ref->{"id"} || "";
    my $type = $header_ref->{"type"} || "";

    my @options = ();
    my @directives = ();
    my @children = ();

    foreach my $record_ref (@{$sect_ref}) {
	my %record = %{$record_ref};
	my $r_type = $record{"type"};
	my $r_key = $record{"key"};
	my $r_ca = $record{"comment_after"};
	my $r_cb = $record{"comment_before"};
	my $r_value = $record{"value"};
	if ($r_type eq "option")
	{
	    push @options, \%record;
	}
	elsif ($r_type eq "directive")
	{
	    push @directives, \%record;
	}
	else
	{
	    my %parent_act_rec = (
		"parent_type" => $type,
		"parent_id" => $id,
		"type" => $r_type,
		"id" => $r_key,
		"comment_before" => $r_cb,
		"comment_after" => $r_ca,
	    );
	    my $new_sect_ref = PreprocessSettings ($r_value, \%parent_act_rec);
	    push @children, {
		"type" => $r_type,
		"id" => $r_key,
	    };
	}
    }
    my %ret = (
	"parent_type" => $parent_type,
	"parent_id" => $parent_id,
	"type" => $type,
	"key" => $id,
	"options" => \@options,
	"directives" => \@directives,
	"children" => \@children,
	"comment_before" => $header_ref->{"comment_before"},
	"comment_after" => $header_ref->{"comment_after"},
    );
    push @settings, \%ret;
}

sub PrepareToSave {
    my $type = $_[0];
    my $id = $_[1];

    #TODO continue here
}


sub FindEntry {
    my $type = $_[0];
    my $id = $_[1];
    my $list_ref = $_[3];



#    foreach my $rec @{}


}

BEGIN {$TYPEINFO{CreateEntry} = [ "function", "boolean", "string", "string", "string", "string" ];}
sub CreateEntry {
    my $type = $_[0];
    my $id = $_[1];
    my $parent_type = $_[2];
    my $parent_id = $_[3];

    my %new_entry = (
	"type" => $type,
	"id" => $id,
	"value" => [],
    );

#    foreach my $entry, 

}

BEGIN {$TYPEINFO{DeleteEntry} = [ "function", "boolean", "string", "string" ];}
sub DeleteEntry {
    my $type = $_[0];
    my $id = $_[1];
}

BEGIN{$TYPEINFO{GetEntryParent} = [ "function", ["map", "string", "string"], "string", "string"];}
sub GetEntryParent {
    my $type = $_[0];
    my $id = $_[1];
}

BEGIN{$TYPEINFO{SetEntryParent} = [ "function", "boolean", "string", "string", "string", "string" ];}
sub SetEntryParent {
    my $type = $_[0];
    my $id = $_[1];
    my $parent_type = $_[2];
    my $parent_id = $_[3];
}

BEGIN{$TYPEINFO{GetChildrenOfEntry} = ["function", ["list", ["map", "string", "string"]], "string", "string"];}
sub GetChildrenOfEntry {
    my $type = $_[0];
    my $id = $_[1];
}

BEGIN{$TYPEINFO{GetEntryRecrds} = ["function", ["map", "any", "any"], "string", "string"];}
sub GetEntryRecords {
    my $type = $_[0];
    my $id = $_[1];
}

BEGIN{$TYPEINFO{SetEntryRecords} = ["function", "boolean", "string", "string", ["map", "any", "any"]];}
sub SetEntryRecords {
    my $type = $_[0];
    my $id = $_[1];
    my %records = %{$_[0]};

}

BEGIN{$TYPEINFO{ExistsEntry} = ["function", "boolean", "string", "string"];}
sub ExistsEntry {
    my $type = $_[0];
    my $id = $_[1];
}

##------------------------------------
BEGIN { $TYPEINFO{Read} = ["function", "boolean"]; }
sub Read {
# Check packages
# TODO

# Information about the daemon

    $start_service = Service::Enabled ("dhcpd");
    y2milestone ("Service start: $start_service");
    $chroot = (SCR::Read (".sysconfig.dhcpd.DHCPD_RUN_CHROOTED") ne "no")
	? 1
	: 0;
    y2milestone ("Chroot: $chroot");
    my $ifaces_list = SCR::Read (".sysconfig.dhcpd.DHCPD_INTERFACE");
    @allowed_interfaces = split (/ /, $ifaces_list);

    my $ag_settings_ref = SCR::Read (".etc.dhcpd_conf");
    @settings = ();
    PreprocessSettings ($ag_settings_ref, {});

print Dumper(\@settings);

    return "true";
}

BEGIN { $TYPEINFO{Write} = ["function", "boolean"]; }
sub Write {
    my $ok = 1;

    if (! $modified)
    {
	return "true";
    }

    #adapt firewall
    $ok = AdaptFirewall () && $ok;

    #save globals
    my @settings_to_save = PrepareToSave ("", "");
    $ok = SCR::Write (".etc.dhcpd_conf", \@settings_to_save) && $ok;

    #set daemon starting
    SCR::Write (".sysconfig.dhcpd.DHCPD_RUN_CHROOTED", $chroot ? "yes" : "no");
    my $ifaces_list = join (" ", @allowed_interfaces);
    SCR::Write (".sysconfig.dhcpd.DHCPD_INTERFACE", $ifaces_list);
    SCR::Write (".sysconfig.dhcpd", undef);

    if ($start_service)
    {
	my $ret = 0;
	if (! $write_only)
	{
	    $ret = SCR::Execute (".target.bash", "/etc/init.d/dhcpd restart");
	}
	Service::Enable ("dhcpd");
	if (0 != $ret)
	{
	    $ok = 0;
	}
    }
    else
    {
	if (! $write_only)
	{
	    SCR::Execute (".target.bash", "/etc/init.d/dhcpd stop");
	}
	Service::Disable ("dhcpd");
    }

    return $ok;
}

BEGIN { $TYPEINFO{Export}  =["function", [ "map", "any", "any" ] ]; }
sub Export {
    my %ret = (
	"start_service" => $start_service,
	"chroot" => $chroot,
	"allowed_interfaces" => \@allowed_interfaces,
	"settings" => \@settings,
    );
    return \%ret;
}
BEGIN { $TYPEINFO{Import} = ["function", "void", [ "map", "any", "any" ] ]; }
sub Import {
    my %settings = %{$_[0]};

    $start_service = $settings{"start_service"} || 0;
    $chroot = $settings{"chroot"} || 1;
    @allowed_interfaces = @{$settings{"allowed_interfaces"} || []};
    @settings = @{$settings{"settings"} || {}};

    $modified = 1;
    $adapt_firewall = 0;
    $write_only = 0;
}

BEGIN { $TYPEINFO{Summary} = ["function", [ "list", "string" ] ]; }
sub Summary {
    my @ret = ();

    if ($start_service)
    {
	# summary string
	push (@ret, _("The DHCP server is started at boot time"));
    }
    else
    {
	# summary string
	push (@ret, _("The DHCP server is not started at boot time"));
    }

    return @ret;
}


# EOF
