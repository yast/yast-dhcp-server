#! /usr/bin/perl -w
#
# DhcpServer module written in Perl
#

package DhcpServer;

use strict;

use ycp;
use YaST::YCP qw(Boolean);
use Data::Dumper;
use Time::localtime;

use Locale::gettext;
use POSIX ();     # Needed for setlocale()

POSIX::setlocale(LC_MESSAGES, "");
textdomain("dhcp-server");

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

my %current_entry = ();

my $current_entry_index = 0;

my $adapt_ddns_settings = 0;



# FIXME this should be defined only once for all modules
sub _ {
    return gettext ($_[0]);
}


YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("Progress");
YaST::YCP::Import ("Report");
YaST::YCP::Import ("Require");
YaST::YCP::Import ("SuSEFirewall");
YaST::YCP::Import ("DhcpTsigKeys");


##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

sub AdaptFirewall {
    if (! $adapt_firewall)
    {
	return 1;
    }

    my $ret = 1;

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
	$ret = SuSEFirewall::Write () && $ret;
	Progress::on ();
    }
    if ($start_service)
    {
	$ret = SCR::Write (".sysconfig.SuSEfirewall2.FW_SERVICE_DHCPD",
	    SuSEFirewall::MostInsecureInterface (\@allowed_interfaces)) && $ret;
    }
    else
    {
	$ret = SCR::Write (".sysconfig.SuSEfirewall2.FW_SERVICE_DHCPD", "no")
	    && $ret;
    }

    $ret = SCR::Write (".sysconfig.SuSEfirewall2", undef) && $ret;
    if (! $write_only)
    {
	$ret = SCR::Execute (".target.bash", "test -x /sbin/rcSuSEfirewall2 && /sbin/rcSuSEfirewall2 status && /sbin/rcSuSEfirewall2 restart") && $ret;
    }
    if (! $ret)
    {
	# error report
	Report::Error (_("Error occurred while setting firewall settings."));
    }
    return $ret;
}

sub InitTSIGKeys {
    my @directives = GetEntryDirectives ("", "");
    my @read_keys = ();
    foreach my $dir_ref (@directives) {
	my %dir = %{$dir_ref};
	if ($dir{"key"} eq "include")
	{
	    my $filename = $dir{"value"};
	    $filename =~ s/^[\" \t]*(.*[^\" \t])[\" \t]*$/$1/;
	    my @new_keys = DhcpTsigKeys::AnalyzeTSIGKeyFile ($filename);
	    foreach my $new_key (@new_keys) {
		y2milestone ("Having key $new_key, file $filename");
		push @read_keys, {
		    "filename" => $filename,
		    "key" => $new_key,
		};
	    }
	}
    }
    DhcpTsigKeys::StoreTSIGKeys (\@read_keys);
}

sub AdaptDDNS {
    # FIXME temporary hack because of testsuite
    if (Mode::test ())
    {
	return 1;
    }
    my @directives = GetEntryDirectives ("", "");
    my %includes = ();

    my @current_keys = DhcpTsigKeys::ListTSIGKeys ();
    my @deleted_keys = DhcpTsigKeys::ListDeletedKeyIncludes ();
    my @new_keys = DhcpTsigKeys::ListNewKeyIncludes ();

    @directives = grep {
	my %dir = %{$_};
	my $ret = 1;
	if ($dir{"key"} eq "include")
	{
	    my $filename = $dir{"value"};
	    $filename =~ s/^[\" \t]*(.*[^\" \t])[\" \t]*$/$1/;
	    my @found = grep {
		$_ eq $filename;
	    } @deleted_keys;
	    if (@found)
	    {
y2error ("not saving $filename");
		$ret = 0;
	    }
	}
	if ($adapt_ddns_settings)
	{
	    if ($dir{"key"} eq "ddns-update-style"
		|| $dir{"key"} eq "ddns-updates"
		|| $dir{"key"} eq "ignore")
	    {
		$ret = 0;
	    }
	}
	$ret;
    } @directives;

    my $includes = SCR::Read (".sysconfig.dhcpd.DHCPD_CONF_INCLUDE_FILES");
    my @includes = split (/ /, $includes);
    @includes = grep {
	my $current_grepped = $_;
	grep {
	    $_ ne $current_grepped
	} @deleted_keys;
    } @includes;
    foreach my $new_inc (@new_keys) {
	push @includes, $new_inc;
	push @directives, {
	    "key" => "include",
	    "value" => "\"$new_inc\"",
	};
    }
    $includes = join (" ", @includes);
    SCR::Write (".sysconfig.dhcpd.DHCPD_CONF_INCLUDE_FILES", $includes);
    SCR::Write (".sysconfig.dhcpd", undef);

    if ($adapt_ddns_settings)
    {
	push @directives, {
	    "key" => "ddns-update-style",
	    "value" => "interim",
	};
	push @directives, {
	    "key" => "ignore",
	    "value" => "client-updates",
	};
	push @directives, {
	    "key" => "ddns-updates",
	    "value" => "on",
	};
    }

    SetEntryDirectives ("", "", \@directives);

    return 1;
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
	"id" => $id,
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

    my $record_index = FindEntry ($type, $id);

    return [] if ($record_index == -1);
    my %record = %{$settings[$record_index]};

    my @to_save = ();
    foreach my $rec_ref (@{$record{"options"}}) {
	my %r = %{$rec_ref};
	$r{"type"} = "option";
	push @to_save, \%r;
    }
    foreach my $rec_ref (@{$record{"directives"}}) {
	my %r = %{$rec_ref};
	$r{"type"} = "directive";
	push @to_save, \%r;
    }

    foreach my $child_ref (@{$record{"children"}}) {
	my $c_type = $child_ref->{"type"};
	my $c_id = $child_ref->{"id"};
	my $processed_child_ref = PrepareToSave ($c_type, $c_id);
	push @to_save, $processed_child_ref;
    }

    if ($type ne "")
    {
	my %r = (
	    "type" => $type,
	    "key" => $id,
	    "comment_before" => $record{"comment_before"},
	    "comment_after" => $record{"comment_after"},
	    "value" => \@to_save,
	);
	return \%r;
    }
    return \@to_save;
}


sub FindEntry {
    my $type = $_[0];
    my $id = $_[1];

    my $index = -1;
    my $found = -1;
    foreach my $rec (@settings) {
	$index = $index + 1;
	if ($rec->{"type"} eq $type && $rec->{"id"} eq $id)
	{
	    $found = $index;
	}
    }
    return $found;
}

BEGIN {$TYPEINFO{CreateEntry} = [ "function", "boolean", "string", "string", "string", "string" ];}
sub CreateEntry {
    my $type = $_[0];
    my $id = $_[1];
    my $parent_type = $_[2];
    my $parent_id = $_[3];

    my $parent_index = FindEntry ($parent_type, $parent_id);
    if ($parent_index == -1)
    {
	y2error ("CreateEntry: Specified non-existing parent entry");
	return 0;
    }

    # create new entry, push it
    my %new_entry = (
	"type" => $type,
	"id" => $id,
	"parent_id" => $parent_id,
	"parent_type" => $parent_type,
	"options", [],
	"directives" => [],
	"children" => [],
	"comment_before" => "",
	"comment_after" => "",
    );

    push @settings, \%new_entry;

    #create link from parent
    my %link = (
	"type" => $type,
	"id" => $id,
    );
    my @par_c = @{$settings[$parent_index]->{"children"}};
    push @par_c, \%link;
    $settings[$parent_index]->{"children"} = \@par_c;

    return 1;
}

BEGIN {$TYPEINFO{DeleteEntry} = [ "function", "boolean", "string", "string" ];}
sub DeleteEntry {
    my $type = $_[0];
    my $id = $_[1];

    if ($type eq "" || $id eq "")
    {
	y2error ("DeleteEntry: Cannot delete root entry");
	return 0;
    }
    my $index = FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("DeleteEntry: Specified non-existint entry");
	return 0;
    }
    my $parent_type = $settings[$index]->{"parent_type"};
    my $parent_id = $settings[$index]->{"parent_id"};
    my @children = @{$settings[$index]->{"children"}};
    foreach my $child_ref (@children) {
	my $c_type = $child_ref->{"type"};
	my $c_id = $child_ref->{"id"};
	DeleteEntry ($c_type, $c_id);
    }
    my $parent_index = FindEntry ($parent_type, $parent_id);
    if ($parent_index == -1)
    {
	y2error ("DeleteEntry: Parent doesn't exist - internal structure error");
    }
    else
    {
	#remove from the list of parent's children
	my @par_children = @{$settings[$parent_index]->{"children"}};
	@par_children = grep {
	    $_->{"type"} ne $type || $_->{"id"} ne $id;
	} @par_children;
	$settings[$parent_index]->{"children"} = \@par_children;
    }

    # delete the record itself
    @settings = grep {
	$_->{"type"} ne $type || $_->{"id"} ne $id;
    } @settings;
}

BEGIN{$TYPEINFO{GetEntryParent} = [ "function", ["map", "string", "string"], "string", "string"];}
sub GetEntryParent {
    my $type = $_[0];
    my $id = $_[1];

    if ($type eq "" || $id eq "")
    {
	y2error ("GetEntryParent: Cannot get parent of root entry");
	return undef;
    }
    my $index = FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("GetEntryParent: Specified non-existint entry");
	return undef;
    }
    my %parent = (
	"type" => $settings[$index]->{"parent_type"},
	"id" => $settings[$index]->{"parent_id"},
    );
    return \%parent;
}

BEGIN{$TYPEINFO{SetEntryParent} = [ "function", "boolean", "string", "string", "string", "string" ];}
sub SetEntryParent {
    my $type = $_[0];
    my $id = $_[1];
    my $new_parent_type = $_[2];
    my $new_parent_id = $_[3];

    if ($type eq "" || $id eq "")
    {
	y2error ("SetEntryParent: Cannot set parent of root entry");
	return 0;
    }
    my $index = FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("SetEntryParent: Specified non-existint entry");
	return 0;
    }
    my $new_parent_index = FindEntry ($new_parent_type, $new_parent_id);
    if ($new_parent_index == -1)
    {
	y2error ("SetEntryParent: Specified non-existint new parent entry");
	return 0;
    }
    my $old_parent_type = $settings[$index]->{"parent_type"};
    my $old_parent_id = $settings[$index]->{"parent_id"};
    my $old_parent_index = FindEntry ($old_parent_type, $old_parent_id);
    if ($old_parent_index == -1)
    {
	y2error ("SetEntryParent: Current parent entry not found.");
	return 0;
    }

    # remove from list of children of old parent    
    %{$settings[$old_parent_index]->{"children"}} = grep {
	$_->{"type"} != $type || $_->{"id"} != $id;
    } %{$settings[$old_parent_index]->{"children"}};
    # add to list of children of new parent
    my %link = (
	"type" => $type,
	"id" => $id,
    );
    push @{$settings[$new_parent_index]->{"children"}}, \%link;
    # change the parent
    $settings[$index]->{"parent_type"} = $new_parent_type;
    $settings[$index]->{"parent_id"} = $new_parent_id;

    return 1;
}

BEGIN{$TYPEINFO{GetChildrenOfEntry} = ["function", ["list", ["map", "string", "string"]], "string", "string"];}
sub GetChildrenOfEntry {
    my $type = $_[0];
    my $id = $_[1];

    my $index = FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("GetChildrenOfEntry: Specified non-existint entry");
	return ();
    }
    @{$settings[$index]->{"children"}};
}

BEGIN{$TYPEINFO{GetEntryOptions} = ["function", ["list", "any"], "string", "string"];}
sub GetEntryOptions {
    my $type = $_[0];
    my $id = $_[1];

    my $index = FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("GetEntryoptions: Specified non-existint entry");
	return undef;
    }
    @{$settings[$index]->{"options"}};
}

BEGIN{$TYPEINFO{SetEntryOptions} = ["function", "boolean", "string", "string", ["list", "any"]];}
sub SetEntryOptions {
    my $type = $_[0];
    my $id = $_[1];
    my @records = @{$_[2]};

    my $index = FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("SetEntryOptions: Specified non-existint entry");
	return 0;
    }
    $settings[$index]->{"options"} = \@records;
    return 1;
}

BEGIN{$TYPEINFO{GetEntryDirectives} = ["function", ["list", "any"], "string", "string"];}
sub GetEntryDirectives {
    my $type = $_[0];
    my $id = $_[1];

    my $index = FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("GetEntryDirectives: Specified non-existint entry");
	return undef;
    }
    @{$settings[$index]->{"directives"}};
}

BEGIN{$TYPEINFO{SetEntryDirectives} = ["function", "boolean", "string", "string", ["list", "any"]];}
sub SetEntryDirectives {
    my $type = $_[0];
    my $id = $_[1];
    my @records = @{$_[2]};

    my $index = FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("SetEntryDirectives: Specified non-existint entry");
	return 0;
    }
    $settings[$index]->{"directives"} = \@records;
    return 1;
}

BEGIN{$TYPEINFO{ExistsEntry} = ["function", "boolean", "string", "string"];}
sub ExistsEntry {
    my $type = $_[0];
    my $id = $_[1];

    my $index = FindEntry ($type, $id);
    $index != -1;
}

BEGIN{$TYPEINFO{ChangeEntry} = ["function", "boolean", "string", "string", "string", "string"];}
sub ChangeEntry {
    my $old_type = $_[0];
    my $old_id = $_[1];
    my $new_type = $_[2];
    my $new_id = $_[3];

    my $index = FindEntry ($old_type, $old_id);
    if ($index == -1)
    {
	y2error ("ChangeEntry: Specified non-existint entry");
	return 0;
    }

    $settings[$index]->{"type"} = $new_type;
    $settings[$index]->{"id"} = $new_id;

    @settings = map {
	my %entry = %{$_};
	if ($entry{"parent_type"} eq $old_type
	    && $entry{"parent_id"} eq $old_id)
	{
	    $entry{"parent_type"} = $new_type;
	    $entry{"parent_id"} = $new_id;
	}
	my @children = @{$entry{"children"}};
	@children = map {
	    my %child = %{$_};
	    if ($child{"type"} eq $old_type && $child{"id"} eq $old_id)
	    {
		$child{"type"} = $new_type;
		$child{"id"} = $new_id;
	    }
	    \%child;
	} @children;
	$entry{"children"} = \@children;
	\%entry;
    } @settings;
    1;
}



##------------------------------------
# Wrappers for accessing local data

BEGIN { $TYPEINFO{GetStartService} = [ "function", "boolean" ];}
sub GetStartService {
    return Boolean($start_service);
}

BEGIN{$TYPEINFO{SetStartService} = ["function", "void", "boolean"];}
sub SetStartService {
    $start_service = $_[0];
}

BEGIN{$TYPEINFO{SetModified} = ["function", "void"];}
sub SetModified {
    $modified = 1;
}

BEGIN { $TYPEINFO{SetWriteOnly} = ["function", "void", "boolean" ]; }
sub SetWriteOnly {
    $write_only = $_[0];
}

BEGIN{$TYPEINFO{GetAllowedInterfaces} = ["function", ["list", "string"] ];}
sub GetAllowedInterfaces {
    return @allowed_interfaces;
}

BEGIN{$TYPEINFO{SetAllowedInterfaces} = ["function", "void", ["list", "string"]];}
sub SetAllowedInterfaces {
    @allowed_interfaces = @{$_[0]};
}

BEGIN{$TYPEINFO{GetAdaptFirewall} = ["function", "boolean"];}
sub GetAdaptFirewall {
    return Boolean($adapt_firewall);
}

BEGIN{$TYPEINFO{SetAdaptFirewall} = ["function", "void", "boolean"];}
sub SetAdaptFirewall {
    $adapt_firewall = $_[0];
}

BEGIN{$TYPEINFO{GetAdaptDdnsSettings} = ["function", "boolean"];}
sub GetAdaptDdnsSettings {
    return Boolean($adapt_ddns_settings);
}
BEGIN{$TYPEINFO{SetAdaptDdnsSettings} = ["function", "void", "boolean"];}
sub SetAdaptDdnsSettings {
    $adapt_ddns_settings = $_[0];
}

##------------------------------------
BEGIN { $TYPEINFO{Read} = ["function", "boolean"]; }
sub Read {

    # Dhcp-server read dialog caption
    my $caption = _("Initializing DHCP Server Configuration");

    Progress::New( $caption, " ", 2, [
	# progress stage
	_("Check the environment"),
	# progress stage
	_("Read the settings"),
    ],
    [
	# progress step
	_("Checking the environment..."),
	# progress step
	_("Reading the settings..."),
	# progress step
	_("Finished")
    ],
    ""
    );

    my $sl = 0.5;
    sleep ($sl);

    Progress::NextStage ();

    if (! (Mode::config () || Require::AreAllPackagesInstalled (["dhcp-server"])))
    {
	my $installed = Require::RequireAndConflictTarget (["dhcp-server"], [],
	# richtext, %1 is name of package
	    _("For running DHCP server, a DHCP daemon is required.
YaST2 will install package %1.
"));
	if (! $installed && ! Require::LastOperationCanceled ())
	{
	    # error popup
	    Report::Error (_("Installing required packages failed."));
	}
    }
 
# Information about the daemon

    Progress::NextStage ();

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

    InitTSIGKeys ();

    Progress::NextStage ();

    return "true";
}

BEGIN { $TYPEINFO{Write} = ["function", "boolean"]; }
sub Write {

    # Dhcp-server read dialog caption */
    my $caption = _("Saving DHCP Server Configuration");

    # We do not set help text here, because it was set outside
    Progress::New($caption, " ", 2, [
	# progress stage
	_("Write the settings"),
	# progress stage
	_("Restart DHCP server"),
    ], [
	# progress step
	_("Writing the settings..."),
	# progress step
	_("Restarting DHCP server..."),
	# progress step
	_("Finished")
    ],
    ""
    );


    my $ok = 1;

    if (! $modified)
    {
	y2milestone ("Nothing modified, nothing to save");
	return Boolean(1);
    }

    Progress::NextStage ();

    #adapt firewall
    $ok = AdaptFirewall () && $ok;

    #adapt dynamic DNS settings
    $ok = AdaptDDNS () && $ok;

    #save globals
    my $settings_to_save_ref = PrepareToSave ("", "");

    $ok = SCR::Write (".etc.dhcpd_conf", $settings_to_save_ref) && $ok;

    Progress::NextStage ();

    #set daemon starting
    SCR::Write (".sysconfig.dhcpd.DHCPD_RUN_CHROOTED", $chroot ? "yes" : "no");
    my $ifaces_list = join (" ", @allowed_interfaces);
    SCR::Write (".sysconfig.dhcpd.DHCPD_INTERFACE", $ifaces_list);
    SCR::Write (".sysconfig.dhcpd", undef);

    if ($start_service)
    {
	y2milestone ("Enabling the DHCP service");
	my $ret = 0;
	if (! $write_only)
	{
	    $ret = SCR::Execute (".target.bash", "/etc/init.d/dhcpd restart");
	}
	Service::Enable ("dhcpd");
	if (0 != $ret)
	{
	    # error report
	    Report::Error (_("Error occurred while restarting DHCP daemon."));
	    $ok = 0;
	}
    }
    else
    {
	y2milestone ("Disabling the DHCP service");
	if (! $write_only)
	{
	    SCR::Execute (".target.bash", "/etc/init.d/dhcpd stop");
	}
	Service::Disable ("dhcpd");
    }

    Progress::NextStage ();

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
