#! /usr/bin/perl -w
#
# DhcpServer module written in Perl
#

package DhcpServer;

use strict;

use YaST::YCP qw(:LOGGING Boolean sformat);

#YaST::YCP::debug (1);

use Data::Dumper;
use Time::localtime;

use YaPI;
textdomain("dhcp-server");

#use io_routines;
#use check_routines;

our %TYPEINFO;

# persistent variables

my $start_service = 0;

my $chroot = 0;

my @allowed_interfaces = ();

my @settings = (
	{
	    "type" => "",
	    "id" => "",
	    "directives" => [],
	    "options" => [],
	    "parent_id" => "",
	    "parent_type" => "",
	    "children" => [],
	},
    );

my @settings_for_ldap = ();

my $base_config_dn = "";

my $ldap_dhcp_config_dn = "";

my $ldap_domain = "";

my $ldap_server = "";

my $ldap_port = "";

my @tsig_keys = ();

#transient variables

my $modified = 0;

my $open_firewall = 0;

my $adapt_firewall = 0;

my $write_only = 0;

my $adapt_ddns_settings = 0;

my $use_ldap = 0;

my $ldap_available = 0;

my $ldap_config_dn = "";

my %yapi_conf = ();

my $dhcp_server = "";

my $dhcp_server_fqdn = "";

my $was_configured = 1;

my $dhcp_server_dn = "";

my @new_include_files = ();

my @deleted_include_files = ();

my @original_allowed_interfaces = ();


YaST::YCP::Import ("SCR");
YaST::YCP::Import ("CWMTsigKeys");
YaST::YCP::Import ("DNS");
YaST::YCP::Import ("Directory");
YaST::YCP::Import ("IP");
YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("LdapServerAccess");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("NetworkDevices");
YaST::YCP::Import ("Netmask");
YaST::YCP::Import ("PackageSystem");
YaST::YCP::Import ("ProductFeatures");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("Popup");
YaST::YCP::Import ("Progress");
YaST::YCP::Import ("Report");
YaST::YCP::Import ("SuSEFirewall");

use lib "/usr/share/YaST2/modules";

##-------------------------------------------------------------------------
##----------------- TSIG Key Management routines --------------------------

BEGIN{$TYPEINFO{ListTSIGKeys}=["function",["list",["map","string","string"]]];}
sub ListTSIGKeys {
    return \@tsig_keys;
}

BEGIN{$TYPEINFO{GetKeysInfo}=["function", ["map", "string", "any"]];}
sub GetKeysInfo {
    my $self = shift;

    return {
	"removed_files" => \@deleted_include_files,
	"new_files" => \@new_include_files,
	"tsig_keys" => \@tsig_keys,
    };
}

BEGIN{$TYPEINFO{SetKeysInfo}=["function", "void", ["map", "string", "any"]];}
sub SetKeysInfo {
    my $self = shift;
    my $info = shift;

    @tsig_keys = @{$info->{"tsig_keys"} };
    @new_include_files = @{$info->{"new_files"} };
    @deleted_include_files = @{$info->{"removed_files"} };
    $self->SetModified ();
}

BEGIN{$TYPEINFO{ListUsedKeys}=["function", ["list","string"]];}
sub ListUsedKeys {
    my $lself = shift;

    my @used_keys = ();

    foreach my $rec (@settings) {
	my @directives = @{$rec->{"directives"}};
	foreach my $dir (@directives) {
	    if ($dir->{"key"} eq "zone")
	    {
		my $val = $dir->{"value"};
		if ($val =~ m/^[ \t]*[^ \t]+[ \t]*\{[ \t]*primary[ \t]+[^ \t]+[ \t]*;[ \t]*key[ \t]+([^ \t]+)[ \t]*;[ \t]*\}[ \t]*$/)
		{
		    push @used_keys, $1;
		}
	    }

	}
    }
    my %used_keys = ();
    foreach my $k (@used_keys) {
	$used_keys{$k} = 1;
    }
    @used_keys = keys (%used_keys);
    return \@used_keys;
}


##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

sub InitTSIGKeys {
    my $self = shift;

    my @directives = @{$self->GetEntryDirectives ("", "") || []};
    my @read_keys = ();
    foreach my $dir_ref (@directives) {
	my %dir = %{$dir_ref};
	if ($dir{"key"} eq "include")
	{
	    my $filename = $dir{"value"};
	    $filename =~ s/^[\" \t]*(.*[^\" \t])[\" \t]*$/$1/;
	    my @new_keys = @{CWMTsigKeys->AnalyzeTSIGKeyFile ($filename)};
	    foreach my $new_key (@new_keys) {
		y2milestone ("Having key $new_key, file $filename");
		push @read_keys, {
		    "filename" => $filename,
		    "key" => $new_key,
		};
	    }
	}
    }
    @tsig_keys = @read_keys;
    @new_include_files = ();
    @deleted_include_files = ();
    return;
}

sub AdaptDDNS {
    my $self = shift;

    # FIXME temporary hack because of testsuite
    if (Mode->test ())
    {
	return 1;
    }
    my @directives = @{$self->GetEntryDirectives ("", "") || []};

    @directives = grep {
	my %dir = %{$_};
	my $ret = 1;
	if ($dir{"key"} eq "include")
	{
	    my $filename = $dir{"value"};
	    $filename =~ s/^[\" \t]*(.*[^\" \t])[\" \t]*$/$1/;
	    my @found = grep {
		$_ eq $filename;
	    } @deleted_include_files;
	    if (@found)
	    {
		y2debug ("not saving $filename");
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

    my $includes = SCR->Read (".sysconfig.dhcpd.DHCPD_CONF_INCLUDE_FILES")|| "";
    my @includes = split (/ /, $includes);
    foreach my $dk (@deleted_include_files) {
        @includes = grep {
	    $_ ne $dk;
	} @includes;
    }
    foreach my $new_inc (@new_include_files) {
	push @includes, $new_inc;
	push @directives, {
	    "key" => "include",
	    "value" => "\"$new_inc\"",
	};
    }
    my %includes = ();
    foreach my $include (@includes) {
	$includes{$include} = 1;
    }
    foreach my $tsig_key (@tsig_keys) {
	my $k_fn = $tsig_key->{"filename"};
	if (! exists ($includes{$k_fn}))
	{
	    y2warning ("Adding file $k_fn to copy to chroot, should already have been there");
	    $includes{$k_fn} = 1;
	}
    }

    @includes = sort (keys (%includes));
    $includes = join (" ", @includes);
    SCR->Write (".sysconfig.dhcpd.DHCPD_CONF_INCLUDE_FILES", $includes);
    SCR->Write (".sysconfig.dhcpd", undef);

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

    $self->SetEntryDirectives ("", "", \@directives);

    return 1;
}

sub PreprocessSettings {
    my $self = shift;
    my $sect_ref = shift;
    my $header_ref = shift;

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
	    my $new_sect_ref = $self->PreprocessSettings ($r_value, \%parent_act_rec);
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
    return;
}

sub PreprocessSettingsFromLdap {
    my $self = shift;
    my $sect_ref = shift;
    my $header_ref = shift;

    my $parent_id = $header_ref->{"parent_id"} || "";
    my $parent_type = $header_ref->{"parent_type"} || "";
    my $id = $header_ref->{"id"} || "";
    my $type = $header_ref->{"type"} || "";
    my $dn = $sect_ref;

    my @options = ();
    my @directives = ();
    my @children = ();
    
    # get sect_ref from LDAP
    
    # the search config map
    my %ldap_query = (
	"base_dn" => $sect_ref,
	"scope" => 0,	# top level only
	"map" => 0	# gimme a list (single entry)
    );
   
    my @found = @{ SCR->Read (".ldap.search", \%ldap_query) || []};

    my %record = %{ $found[0] || {}};
    
    # determine type
    my @classes = @{ $record { "objectclass" } || [] };

    if ( grep ( /dhcpOptions/, @classes ) && defined $record { "dhcpoption" } )
    {
	# there are some options to gather
	my @opts = @{ $record { "dhcpoption" } };
	foreach my $opt (@opts) {
	    # split by spaces
	    my @single = split (/ +/, $opt);
	    my $key = shift @single;
	    my $value = join ( " ", @single );
	    if ((! defined ($value)) || $value eq "")
	    {
		$value = "__true";
	    }
	    my %option_rec = (
		"key" => $key,
		"value" => $value,
		"type" => "option",
		"comment_before" => "",
		"comment_after" => ""
	    );
	    push @options, \%option_rec;
	}
    }
    
    if ( defined $record { "dhcpstatements" } )
    {
	my @statements = @{ $record { "dhcpstatements" } };
	# there are some directives to gather
	foreach my $stmt (@statements) {
	    # split by spaces
	    my @single = split (/ +/, $stmt);
	    my $key = shift @single;
	    my $value = join ( " ", @single );
	    if ((! defined ($value)) || $value eq "")
	    {
		$value = "__true";
	    }
	    my %directive_rec = (
		"key" => $key,
		"value" => $value,
		"type" => "directive",
		"comment_before" => "",
		"comment_after" => ""
	    );
	    push @directives, \%directive_rec;
	}
    }
    
    # now handle also special case statements
    if ( $type eq "host" && defined $record { "dhcphwaddress" } )
    {
	my %directive_rec = (
		"key" => "hardware",
		"value" => $record { "dhcphwaddress" }->[0],
		"type" => "directive",
		"comment_before" => "",
		"comment_after" => ""
	    );
	push @directives, \%directive_rec;
    }
    elsif ( ($type eq "pool" || $type eq "subnet" ) && defined $record { "dhcprange" } )
    {
	my %directive_rec = (
		"key" => "range",
		"value" => $record { "dhcprange" }->[0],
		"type" => "directive",
		"comment_before" => "",
		"comment_after" => ""
	    );
	push @directives, \%directive_rec;
    }
    
    my $r_key = $record{"key"} || "";
    my $r_ca = "";	# no comments in LDAP
    my $r_cb = ""; 	# no comments in LDAP
    my $r_value = $record{"value"} || "";
    
    # now, look for the children
    %ldap_query = (
	"base_dn" => $sect_ref,
	"scope" => 1,	# one level only
	"map" => 1,	# gimme a map
	"not_found_ok" => 1,
    );
    
    my %child_hash = %{ SCR->Read (".ldap.search", \%ldap_query) || {}};
    
    foreach my $child (sort keys %child_hash)
    {

	# the search config map
	%ldap_query = (
	    "base_dn" => $child,
	    "scope" => 0,   # top level only
	    "map" => 0      # gimme a list (single entry)
	); 
    
	@found = @{ SCR->Read (".ldap.search", \%ldap_query) };

	my %child_record = %{ $found[0] };

	my $r_type = undef;

	# determine type
	my @classes = @{ $child_record { "objectclass" } };

	if ( grep ( /dhcpPool/, @classes ) )
	{
	    $r_type = "pool";	    
	}
	elsif ( grep ( /dhcpClass/, @classes ) )
	{
	    $r_type = "class";
	}
	elsif ( grep ( /dhcpSubnet/, @classes ) )
	{
	    $r_type = "subnet";
	}
	elsif ( grep ( /dhcpHost/, @classes ) )
	{
	    $r_type = "host";
	}
	elsif ( grep ( /dhcpSharedNetwork/, @classes ) )
	{
	    $r_type = "sharednetwork";
	}
	elsif ( grep ( /dhcpGroup/, @classes ) )
	{
	    $r_type = "group";
	}
	else
	{
	    $r_type = ""; # general settings????
	}

	my @cns = @{ $child_record { "cn" } }; 
	my $r_id = $cns[0];

	if ($r_type eq "subnet")
	{
	    my @netmasks = @{ $child_record { "dhcpnetmask" } };
	    my $netmask = $netmasks[0];
	    $netmask = Netmask->FromBits ($netmask);
	    $r_id = "$r_id netmask $netmask";
	}

	my %parent_act_rec = (
	    "parent_type" => $type,
	    "parent_id" => $id,
	    "type" => $r_type,
	    "id" => $r_id,
	    "comment_before" => "",
	    "comment_after" => "",
	);
	my $new_sect_ref = $self->PreprocessSettingsFromLdap ( $child, \%parent_act_rec);	
	push @children, {
	    "type" => $r_type,
	    "id" => $r_id,
	};
    }
    
    my %ret = (
	"parent_type" => $parent_type,
	"parent_id" => $parent_id,
	"type" => $type,
	"id" => $id,
	"options" => \@options,
	"directives" => \@directives,
	"children" => \@children,
	"comment_before" => "",
	"comment_after" => "",
	"ldap_dn" => $dn,
	"ldap_original_content" => \%record,
    );
    push @settings, \%ret;

    return;
}

sub SaveToLdap {
    my $self = shift;
    my $type = shift;
    my $id = shift;
    my $parent_dn = shift;		# for the top level it is undefined and unused

    my $record_index = $self->FindEntry ($type, $id);

    return undef if ($record_index == -1);
    my %record = %{$settings[$record_index]};

    my %where_rec = (
	"dn" => $record { "ldap_dn" } || $ldap_dhcp_config_dn,
	"check_attrs" => 1,	# don't check those missing attributes
    );
    
    my $newly_added = 0;
    my $moved = 0;
    
    if ( ! defined $record { "ldap_dn" } )
    {
	$newly_added = 1;
    }
    
    my %to_save = ();
    
    my @opts = map {
	if ($_->{"value"} eq "__true")
	{
	    $_->{"value"} = "";
	}
	elsif ($_->{"value"} eq "__false")
	{
	    $_ = undef;
	}
	$_;
    } @{$record{"options"}};
    @opts = grep {
	defined ($_);
    } @opts;
    my @dirs = map {
	if ($_->{"value"} eq "__true")
	{
	    $_->{"value"} = "";
	}
	elsif ($_->{"value"} eq "__false")
	{
	    $_ = undef;
	}
	$_;
    } @{$record{"directives"}};
    @dirs = grep {
	defined ($_);
    } @dirs;

    my @options = ();
    foreach my $rec_ref (@opts) {
	my %r = %{$rec_ref};
	my $opt = $r { "key" } . " " . ($r { "value" } || "");
	if ((! defined ($r{"value"})) || $r{"value"} eq "")
	{
	    $opt = $r { "key" };
	}
	push @options, $opt;
    }
    
    my @directives = ();
    foreach my $rec_ref (@dirs) {
	my %r = %{$rec_ref};
	
	#handle special cases differently
	if ( $record { "type" } eq "host" && $r { "key" } eq "hardware" )
	{
	    my $val = $r { "value" };
	    my @lval = split (/ /, $val);
	    @lval = grep { $_ ne ''; } @lval;
	    $val = join (" ", @lval);
	    $val = lc ($val);
	    $to_save { "dhcphwaddress" } = $val;
	}
	elsif ( ($record { "type" } eq "pool" || $record { "type" } eq "subnet" ) 
	    && $r { "key" } eq "range" )
	{
	    $to_save { "dhcprange" } = $r { "value" };
	}
	else 
	{
	    my $opt = $r { "key" } . " " . ($r { "value" } || "");
	    if ((! defined ($r{"value"})) || $r{"value"} eq "")
	    {
		$opt = $r { "key" };
	    }
	    push @directives, $opt;
	}
    }

    $to_save { "dhcpoption" } = \@options;
    $to_save { "dhcpstatements" } = \@directives;
    
    # now, add the type-specific options (required attributes)
    if ( $record {"type"} eq "subnet" )
    {
	# dhcpNetMask is required
	$record { "id" } =~ m/^\s*(\S+)\s+netmask\s+([^ \t]+)[ \t]*$/;
	my $id = $1;
	my $netmask = $2;
	$to_save { "dhcpnetmask" } = \@{ [ Netmask->ToBits ( $netmask ) ] };
	
	$to_save { "objectclass" } = \@{ [ "dhcpSubNet", "dhcpOptions", "top" ] };
	$to_save { "cn" } = \@{ [ $id ] };
    }
    elsif ( $record {"type"} eq "pool" )
    {
	$record { "id" } =~ m/^\s*(\S+)\s*$/;
	my $id = $1;
	
	$to_save { "objectclass" } = \@{ [ "dhcpPool", "dhcpOptions", "top" ] };
	$to_save { "cn" } = \@{ [ $id ] };
    }
    elsif ( $record {"type"} eq "class" )
    {
	$record { "id" } =~ m/^\s*(\S+)\s*$/;
	my $id = $1;
	
	$to_save { "objectclass" } = \@{ [ "dhcpClass", "dhcpOptions", "top" ] };
	$to_save { "cn" } = \@{ [ $id ] };
    }
    elsif ( $record {"type"} eq "host" )
    {
	$record { "id" } =~ m/^\s*(\S+)\s*$/;
	my $id = $1;
	
	$to_save { "objectclass" } = \@{ [ "dhcpHost", "dhcpOptions", "top" ] };
	$to_save { "cn" } = \@{ [ $id ] };
    }
    elsif ( $record {"type"} eq "sharednetwork" )
    {
	$record { "id" } =~ m/^\s*(\S+)\s*$/;
	my $id = $1;
	
	$to_save { "objectclass" } = \@{ [ "dhcpSharedNetwork", "dhcpOptions", "top" ] };
	$to_save { "cn" } = \@{ [ $id ] };
    }
    elsif ( $record {"type"} eq "group" )
    {
	$record { "id" } =~ m/^\s*(\S+)\s*$/;
	my $id = $1;
	
	$to_save { "objectclass" } = \@{ [ "dhcpGroup", "dhcpOptions", "top" ] };
	$to_save { "cn" } = \@{ [ $id ] };
    }
    elsif ( $record {"type"} eq "")
    {
	$where_rec{"dn"} =~ m/cn=([^,]+),.*/;
	my $root_cn = $1;
	$to_save{"cn"} = $root_cn if (defined ($root_cn));
	$to_save{"objectclass"} = [ "dhcpService", "dhcpOptions", "top"];
	$to_save{"dhcpprimarydn"} = $dhcp_server_dn;
    }
    
    if ( $record {"type"} ne "" )
    {
	# for non-global entry update dn
	my $dn = "cn=" . $to_save { "cn" }->[0] . "," . $parent_dn; 

	if ( ! $newly_added && $dn ne $record { "ldap_dn" } )
	{
	    # we need to rename the object
	    $where_rec {"dn"} = $record { "ldap_dn" };
	    $where_rec { "rdn" } = "cn=" . $to_save { "cn" }->[0];
	    $where_rec { "new_dn" } = $dn;
	    $where_rec { "deleteOldRDN" } = 1;
	    $where_rec { "subtree" } = 1;
	}
	else
	{
	    $where_rec {"dn"} = $dn;
	}

	$settings[$record_index]-> {"ldap_dn"} = $dn;
    }
    
    if ( defined $record {"ldap_original_content"} )
    {
	# if there was some original content, use it but replace
	# the new values
	my %new_to_save = %{ $record {"ldap_original_content"} };
	foreach my $data (keys (%to_save))
	{
	    $new_to_save { $data } = $to_save { $data };
	}
	%to_save = %new_to_save;
    }
    
    my $path = $newly_added ? ".ldap.add" : ".ldap.modify";

    if ( !SCR->Write ( $path, \%where_rec, \%to_save ) )
    {
	# something bad happened
	my %error = %{ SCR->Read (".ldap.error") };
	if ( $error {"code"} == 68 )
	{
	    # it already exists
	    if ($newly_added)
	    {
		# user has deleted the old one and created a new one
		# we can safely delete the old one
		$where_rec { "subtree" } = 1;
		SCR->Write (".ldap.delete", \%where_rec);
		# retry
		SCR->Write ( ".ldap.add", \%where_rec, \%to_save );
	    }
	}
    }
    
    foreach my $child_ref (@{$record{"children"}}) {
	my $c_type = $child_ref->{"type"};
	my $c_id = $child_ref->{"id"};
	my $processed_child_ref = $self->SaveToLdap ($c_type, $c_id, $where_rec { "dn" } );
    }
    
    # now, remove the unknown ones
    # create a list of known DNs
    my @known_dn = ();
    foreach my $child_ref (@{$record{"children"}}) {
	my $c_type = $child_ref->{"type"};
	my $c_id = $child_ref->{"id"};
	my $record_index = $self->FindEntry ($c_type, $c_id);
	
	if ( defined $record_index )
	{
	    push (@known_dn, $settings[$record_index]->{"ldap_dn"});
	}
    }
    
    y2debug ("Known DNs: " . Dumper (\@known_dn));

    # get the existing ones   
    my %ldap_query = (
	"base_dn" => $where_rec {"dn"},
	"scope" => 1,		# direct sub-level only
	"dn_only" => 1,		# just a list of found DNs
	"not_found_ok" => 1,	# don't spit an error
    );
    
    y2debug ("Looking up: " . Dumper (\%ldap_query) );
    
    my @found = @{ SCR->Read (".ldap.search", \%ldap_query) || []};

    y2debug ("Found: " . Dumper (\@found) );
    
    foreach my $found_rec (@found) {
	if (! grep (/^${found_rec}$/, @known_dn)) {
	    y2milestone ("Deleting unknown DN $found_rec");
	    my %ldap_delete = (
		"dn" => $found_rec,
		"subtree" => 1,
	    );
	    SCR->Write (".ldap.delete", \%ldap_delete);
	}
    }
    
    # success
    return 1;
}


sub PrepareToSave {
    my $self = shift;
    my $type = shift;
    my $id = shift;

    my $record_index = $self->FindEntry ($type, $id);

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
        my $processed_child_ref = $self->PrepareToSave ($c_type, $c_id);
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
    my $self = shift;
    my $type = shift;
    my $id = shift;

    my $index = -1;
    my $found = -1;
    foreach my $rec (@settings) {
	$index = $index + 1;
	if (($rec->{"type"} || "") eq $type && ($rec->{"id"} || "") eq $id)
	{
	    $found = $index;
	}
    }
    return $found;
}

BEGIN {$TYPEINFO{CreateEntry} = [ "function", "boolean", "string", "string", "string", "string" ];}
sub CreateEntry {
    my $self = shift;
    my $type = shift;
    my $id = shift;
    my $parent_type = shift;
    my $parent_id = shift;

    my $parent_index = $self->FindEntry ($parent_type, $parent_id);
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
    my @par_c = @{$settings[$parent_index]->{"children"} || []};
    push @par_c, \%link;
    $settings[$parent_index]->{"children"} = \@par_c;

    $modified = 1;
    return 1;
}

BEGIN {$TYPEINFO{EntryExists} = [ "function", "boolean", "string", "string" ];}
sub EntryExists {
    my $self = shift;
    my $type = shift;
    my $id = shift;

    my $index = $self->FindEntry ($type, $id);
    if ($index == -1)
    {
	return Boolean(0);
    }
    
    return Boolean(1);
}

BEGIN {$TYPEINFO{DeleteEntry} = [ "function", "boolean", "string", "string" ];}
sub DeleteEntry {
    my $self = shift;
    my $type = shift;
    my $id = shift;

    if ($type eq "" || $id eq "")
    {
	y2error ("DeleteEntry: Cannot delete root entry");
	return 0;
    }
    my $index = $self->FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("DeleteEntry: Specified non-existint entry");
	return 0;
    }
    my $parent_type = $settings[$index]->{"parent_type"} || "";
    my $parent_id = $settings[$index]->{"parent_id"} || "";
    my @children = @{$settings[$index]->{"children"} || []};
    foreach my $child_ref (@children) {
	my $c_type = $child_ref->{"type"};
	my $c_id = $child_ref->{"id"};
	$self->DeleteEntry ($c_type, $c_id);
    }
    my $parent_index = $self->FindEntry ($parent_type, $parent_id);
    if ($parent_index == -1)
    {
	y2error ("DeleteEntry: Parent doesn't exist - internal structure error");
	return 0;
    }
    else
    {
	#remove from the list of parent's children
	my @par_children = @{$settings[$parent_index]->{"children"} || []};
	@par_children = grep {
	    $_->{"type"} ne $type || $_->{"id"} ne $id;
	} @par_children;
	$settings[$parent_index]->{"children"} = \@par_children;
    }

    # delete the record itself
    @settings = grep {
	$_->{"type"} ne $type || $_->{"id"} ne $id;
    } @settings;
    $modified = 1;
    return 1;
}

BEGIN{$TYPEINFO{GetEntryParent} = [ "function", ["map", "string", "string"], "string", "string"];}
sub GetEntryParent {
    my $self = shift;
    my $type = shift;
    my $id = shift;

    if ($type eq "" || $id eq "")
    {
	y2error ("GetEntryParent: Cannot get parent of root entry");
	return undef;
    }
    my $index = $self->FindEntry ($type, $id);
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
    my $self = shift;
    my $type = shift;
    my $id = shift;
    my $new_parent_type = shift;
    my $new_parent_id = shift;

    if ($type eq "" || $id eq "")
    {
	y2error ("SetEntryParent: Cannot set parent of root entry");
	return 0;
    }
    my $index = $self->FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("SetEntryParent: Specified non-existint entry");
	return 0;
    }
    my $new_parent_index = $self->FindEntry ($new_parent_type, $new_parent_id);
    if ($new_parent_index == -1)
    {
	y2error ("SetEntryParent: Specified non-existint new parent entry");
	return 0;
    }
    my $old_parent_type = $settings[$index]->{"parent_type"};
    my $old_parent_id = $settings[$index]->{"parent_id"};
    my $old_parent_index = $self->FindEntry ($old_parent_type, $old_parent_id);
    if ($old_parent_index == -1)
    {
	y2error ("SetEntryParent: Current parent entry not found.");
	return 0;
    }

    # remove from list of children of old parent    
    @{$settings[$old_parent_index]->{"children"}} = grep {
	$_->{"type"} ne $type || $_->{"id"} ne $id;
    } @{$settings[$old_parent_index]->{"children"} || []};
    # add to list of children of new parent
    my %link = (
	"type" => $type,
	"id" => $id,
    );
    push @{$settings[$new_parent_index]->{"children"}}, \%link;
    # change the parent
    $settings[$index]->{"parent_type"} = $new_parent_type;
    $settings[$index]->{"parent_id"} = $new_parent_id;

    $modified = 1;
    return 1;
}

BEGIN{$TYPEINFO{GetChildrenOfEntry} = ["function", ["list", ["map", "string", "string"]], "string", "string"];}
sub GetChildrenOfEntry {
    my $self = shift;
    my $type = shift;
    my $id = shift;

    my $index = $self->FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("GetChildrenOfEntry: Specified non-existint entry");
	return ();
    }
    return \@{$settings[$index]->{"children"}};
}

BEGIN{$TYPEINFO{GetEntryOptions} = ["function", ["list", ["map", "string", "string"]], "string", "string"];}
sub GetEntryOptions {
    my $self = shift;
    my $type = shift;
    my $id = shift;

    my $index = $self->FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("GetEntryoptions: Specified non-existint entry");
	return undef;
    }
    return \@{$settings[$index]->{"options"}};
}

BEGIN{$TYPEINFO{SetEntryOptions} = ["function", "boolean", "string", "string", ["list", ["map", "string", "string"]]];}
sub SetEntryOptions {
    my $self = shift;
    my $type = shift;
    my $id = shift;
    my $records_ref = shift;

    my @records = @{$records_ref};

    my $index = $self->FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("SetEntryOptions: Specified non-existint entry");
	return 0;
    }
    $settings[$index]->{"options"} = \@records;
    $modified = 1;
    return 1;
}

BEGIN{$TYPEINFO{GetEntryDirectives} = ["function", ["list", ["map", "string", "string"]], "string", "string"];}
sub GetEntryDirectives {
    my $self = shift;
    my $type = shift;
    my $id = shift;

    my $index = $self->FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("GetEntryDirectives: Specified non-existint entry");
	return undef;
    }
    return \@{$settings[$index]->{"directives"}};
}

BEGIN{$TYPEINFO{SetEntryDirectives} = ["function", "boolean", "string", "string", ["list", ["map", "string", "string"]]];}
sub SetEntryDirectives {
    my $self = shift;
    my $type = shift;
    my $id = shift;
    my $records_ref = shift;
    my @records = @{$records_ref};

    my $index = $self->FindEntry ($type, $id);
    if ($index == -1)
    {
	y2error ("SetEntryDirectives: Specified non-existint entry");
	return 0;
    }
    $settings[$index]->{"directives"} = \@records;
    $modified = 1;
    return 1;
}

BEGIN{$TYPEINFO{ExistsEntry} = ["function", "boolean", "string", "string"];}
sub ExistsEntry {
    my $self = shift;
    my $type = shift;
    my $id = shift;

    my $index = $self->FindEntry ($type, $id);
    return $index != -1;
}

BEGIN{$TYPEINFO{ChangeEntry} = ["function", "boolean", "string", "string", "string", "string"];}
sub ChangeEntry {
    my $self = shift;
    my $old_type = shift;
    my $old_id = shift;
    my $new_type = shift;
    my $new_id = shift;

    my $index = $self->FindEntry ($old_type, $old_id);
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
    $modified = 1;
    return 1;
}



##------------------------------------
# Wrappers for accessing local data

BEGIN { $TYPEINFO{GetStartService} = [ "function", "boolean" ];}
sub GetStartService {
    my $self = shift;

    return Boolean($start_service);
}

BEGIN{$TYPEINFO{SetStartService} = ["function", "void", "boolean"];}
sub SetStartService {
    my $self = shift;
    $start_service = shift;

    $self->SetModified ();
}

BEGIN { $TYPEINFO{SetChrootJail} = [ "function", "void", "boolean" ];}
sub SetChrootJail {
    my $self = shift;
    $chroot = shift;

    $self->SetModified ();
}

BEGIN { $TYPEINFO{GetChrootJail} = [ "function", "boolean" ];}
sub GetChrootJail {
    my $self = shift;

    return Boolean($chroot);
}

BEGIN{$TYPEINFO{SetModified} = ["function", "void"];}
sub SetModified {
    my $self = shift;

    $modified = 1;
}

BEGIN{$TYPEINFO{GetModified} = ["function", "boolean"];}
sub GetModified {
    my $self = shift;

    return Boolean ($modified);
}

BEGIN { $TYPEINFO{SetWriteOnly} = ["function", "void", "boolean" ]; }
sub SetWriteOnly {
    my $self = shift;

    $write_only = shift;
}

BEGIN{$TYPEINFO{GetAllowedInterfaces} = ["function", ["list", "string"] ];}
sub GetAllowedInterfaces {
    my $self = shift;

    return \@allowed_interfaces;
}

BEGIN{$TYPEINFO{SetAllowedInterfaces} = ["function", "void", ["list", "string"]];}
sub SetAllowedInterfaces {
    my $self = shift;
    my $allowed_interfaces_ref = shift;

    @allowed_interfaces = @{$allowed_interfaces_ref};
    $self->SetModified ();
}

BEGIN{$TYPEINFO{GetOpenFirewall} = ["function", "boolean"];}
sub GetOpenFirewall {
    my $self = shift;

    return Boolean($open_firewall);
}

BEGIN{$TYPEINFO{SetOpenFirewall} = ["function", "void", "boolean"];}
sub SetOpenFirewall {
    my $self = shift;
    my $new_open_firewall = shift;

    if ($new_open_firewall != $open_firewall)
    {
	$adapt_firewall = 1;
	$open_firewall = $new_open_firewall;
    }
    $self->SetModified ();
}

BEGIN{$TYPEINFO{GetAdaptDdnsSettings} = ["function", "boolean"];}
sub GetAdaptDdnsSettings {
    my $self = shift;

    return Boolean($adapt_ddns_settings);
}
BEGIN{$TYPEINFO{SetAdaptDdnsSettings} = ["function", "void", "boolean"];}
sub SetAdaptDdnsSettings {
    my $self = shift;
    $adapt_ddns_settings = shift;
    $self->SetModified ();
}

BEGIN{$TYPEINFO{GetUseLdap} = ["function", "boolean"];}
sub GetUseLdap {
    my $self = shift;

    return Boolean($use_ldap);
}
BEGIN{$TYPEINFO{SetUseLdap} = ["function", "void", "boolean"];}
sub SetUseLdap {
    my $self = shift;
    $use_ldap = shift;

    $self->SetModified ();
}

##------------------------------------

BEGIN { $TYPEINFO{AutoPackages} = ["function", ["map","any","any"]];}
sub AutoPackages {
    my $self = shift;

    return {
	"install" => ["dhcp-server"],
	"remote" => [],
    }
}

BEGIN { $TYPEINFO{Read} = ["function", "boolean"]; }
sub Read {
    my $self = shift;

    # Dhcp-server read dialog caption
    my $caption = __("Initializing DHCP Server Configuration");

    Progress->New( $caption, " ", 3, [
	# progress stage
	__("Check the environment"),
	# progress stage
	__("Read firewall settings"),
	# progress stage
	__("Read DHCP server settings"),
    ],
    [
	# progress step
	__("Checking the environment..."),
	# progress step
	__("Reading firewall settings..."),
	# progress step
	__("Reading DHCP server settings..."),
	# progress step
	__("Finished")
    ],
    ""
    );

    my $sl = 0.5;
    sleep ($sl);

    Progress->NextStage ();

    if (! Mode->test ()
	&& ! PackageSystem->CheckAndInstallPackagesInteractive (["dhcp-server"])
    )
    {
	return Boolean (0);
    }

    # initialize the host name of the LDAP server
    $dhcp_server = undef;
    my $out = SCR->Execute (".target.bash_output", "/bin/hostname --short");
    if ($out->{"exit"} == 0)
    {
	my $stdout = $out->{"stdout"};
	my ($hn, $rest) = split ("\n", $stdout, 2);
	if ($hn ne "")
	{
	    $dhcp_server = $hn;
	}
    }
    $dhcp_server_fqdn = undef;
    $out = SCR->Execute (".target.bash_output", "/bin/hostname --fqdn");
    if ($out->{"exit"} == 0)
    {
	my $stdout = $out->{"stdout"};
	my ($hn, $rest) = split ("\n", $stdout, 2);
	if ($hn ne "")
	{
	    $dhcp_server_fqdn = $hn;
	}
    }
    if (! (defined ($dhcp_server) && defined($dhcp_server_fqdn)))
    {
	# error report
	Report->Error (__("Cannot determine the host name of"));
	return 0;
    }

# Firewall settings

    Progress->NextStage ();

    if (! Mode->test ())
    {
	my $progress_orig = Progress->set (0);
	SuSEFirewall->Read ();
	Progress->set ($progress_orig);
    }

# Information about the daemon

    Progress->NextStage ();

    $start_service = Service->Enabled ("dhcpd");
    y2milestone ("Service start: $start_service");
    $chroot = ((SCR->Read (".sysconfig.dhcpd.DHCPD_RUN_CHROOTED")||"") ne "no")
	? 1
	: 0;
    y2milestone ("Chroot: $chroot");
    my $ifaces_list = SCR->Read (".sysconfig.dhcpd.DHCPD_INTERFACE") || "";
    @allowed_interfaces = split (/ /, $ifaces_list);

    @settings = ();
    my $ag_settings_ref = SCR->Read (".etc.dhcpd_conf");
    
    y2debug ( Dumper ($ag_settings_ref) );

    if (SCR->Read (".target.size", "/etc/dhcpd.conf") < 1)
    {
	y2milestone ("/etc/dhcpd.conf not found or empty");
	$was_configured = 0;
    }
    else
    {
	my $diff_out = SCR->Execute (".target.bash", "diff -q /etc/dhcpd.conf \\
             /usr/share/doc/packages/dhcp-server/dhcpd.conf");
	my $using_sample = int(0 == $diff_out);
	if ($using_sample)
	{
	    y2milestone ("Sample configuration file found");
	    # yes-no popup
	    my $question = __("The DHCP server does not seem to have been
configured yet. Create a new configuration?");
	    $ag_settings_ref = [];
	    @allowed_interfaces = ();
	    $was_configured = 0;
	}
    }
    if (scalar (@allowed_interfaces) == 0)
    {
	y2milestone ("No interface was set to listen to!");
	$was_configured = 0;
    }
    if (scalar (keys (%{SCR->Read (".target.stat", Directory->vardir () . "/dhcp_server_done_once") || {}})) == 0)
    {
	y2milestone ("DHCP configuration hadn't been saved properly before");
	$was_configured = 0;
    }

    $self->LdapInit ($ag_settings_ref, 0);
    
    if ( ! $use_ldap )
    {
	# no LDAP, use the standard read
	$self->PreprocessSettings ($ag_settings_ref, {});

	@settings = map {
	    if ($_->{"type"} eq "" && $_->{"id"} eq "")
	    {
		my @directives = @{$_->{"directives"} || []};
		@directives = grep {
		    ! ($_->{"key"} =~ /^[ \t]*ldap-.*$/);
		} @directives;
		$_->{"directives"} = \@directives;
	    }
	    $_;
	} @settings;
    }
    else
    {
	# do LDAP
	y2milestone ("Base Config DN: $base_config_dn");

	$self->PreprocessSettingsFromLdap ($ldap_dhcp_config_dn, {});
    }
    
    $self->InitTSIGKeys ();

    @original_allowed_interfaces = @allowed_interfaces;

    Progress->NextStage ();

    return "true";
}

BEGIN { $TYPEINFO{Write} = ["function", "boolean"]; }
sub Write {
    my $self = shift;

    # Dhcp-server read dialog caption */
    my $caption = __("Saving DHCP Server Configuration");

    # We do not set help text here, because it was set outside
    Progress->New($caption, " ", 3, [
	# progress stage
	__("Write DHCP server settings"),
	# progress stage
	__("Write firewall settings"),
	# progress stage
	__("Restart DHCP server"),
    ], [
	# progress step
	__("Writing DHCP server settings..."),
	# progress step
	__("Writing firewall settings..."),
	# progress step
	__("Restarting DHCP server..."),
	# progress step
	__("Finished")
    ],
    ""
    );


    my $ok = 1;

    $modified = $modified || SuSEFirewall->GetModified ();

    if (! $modified)
    {
	y2milestone ("Nothing modified, nothing to save");
	return Boolean(1);
    }

    Progress->NextStage ();

    #adapt dynamic DNS settings
    $ok = $self->AdaptDDNS () && $ok;

    @settings = map {
	my %decl = %{$_};
	if ($decl{"type"} eq "" && $decl{"id"} eq "")
	{
	    my @direct = @{$decl{"directives"} || []};
	    my @us = grep {
		$_->{"key"} eq "ddns-update-style";
	    } @direct;
	    if (0 == scalar (@us))
	    {
		push @direct, {
		    "key" => "ddns-update-style",
		    "value" => "none",
		};
	    }
	    $decl{"directives"} = \@direct;
	}
	\%decl;
    } @settings;

    #save globals
    if ( ! $use_ldap )
    {
	# no LDAP
	my $settings_to_save_ref = $self->PrepareToSave ("", "");

	$ok = SCR->Write (".etc.dhcpd_conf", $settings_to_save_ref) && $ok;
    }
    else
    {
	# LDAP
	$ok = $self->LdapPrepareToWrite () && $ok;
	$self->SaveToLdap ("","");
    }

    $ok = LdapStore () && $ok;

# Firewall settings

    Progress->NextStage ();

    if (scalar (@original_allowed_interfaces) != scalar (@allowed_interfaces)
	&& $open_firewall)
    {
	$adapt_firewall = 1;
    }

    my %old_ifaces = ();
    foreach my $i (@original_allowed_interfaces) {
	$old_ifaces{$i} = 0;
    }
    foreach my $i (@allowed_interfaces) {
	if (! exists $old_ifaces{$i})
	{
	    if ($open_firewall)
	    {
		$adapt_firewall = 1;
	    }	
	}
    }

    if ($adapt_firewall)
    {
	SuSEFirewall->SetServices (["dhcp-server"], [], 0);
	SuSEFirewall->SetServices (["dhcp-server"], \@allowed_interfaces, 0);
    }

    if (! Mode->test ())
    {
	my $progress_orig = Progress->set (0);
	SuSEFirewall->Write ();
	Progress->set ($progress_orig);
    }

# Set daemon starting
    Progress->NextStage ();

    SCR->Write (".sysconfig.dhcpd.DHCPD_RUN_CHROOTED", $chroot ? "yes" : "no");
    my $ifaces_list = join (" ", @allowed_interfaces);
    SCR->Write (".sysconfig.dhcpd.DHCPD_INTERFACE", $ifaces_list);
    SCR->Write (".sysconfig.dhcpd", undef);

    if ($start_service)
    {
	y2milestone ("Enabling the DHCP service");
	my $ret = 0;
	if (! $write_only)
	{
	    $ret = SCR->Execute (".target.bash", "/etc/init.d/dhcpd restart");
	}
	Service->Enable ("dhcpd");
	if (0 != $ret)
	{
	    # error report
	    Report->Error (__("Error occurred while restarting DHCP daemon."));
	    $ok = 0;
	}
    }
    else
    {
	y2milestone ("Disabling the DHCP service");
	if (! $write_only)
	{
	    SCR->Execute (".target.bash", "/etc/init.d/dhcpd stop");
	}
	Service->Disable ("dhcpd");
    }

    Progress->NextStage ();

    return Boolean ($ok);
}

BEGIN { $TYPEINFO{Export}  =["function", [ "map", "any", "any" ] ]; }
sub Export {
    my $self = shift;

    my %ret = (
	"start_service" => $start_service,
	"chroot" => $chroot,
	"use_ldap" => $use_ldap,
	"allowed_interfaces" => \@allowed_interfaces,
	"settings" => \@settings,
    );
    return \%ret;
}
BEGIN { $TYPEINFO{Import} = ["function", "void", [ "map", "any", "any" ] ]; }
sub Import {
    my $self = shift;
    my $settings_ref = shift;
    my %settings = %{$settings_ref};

    my $default_settings = [
	{
	    "type" => "",
	    "id" => "",
	    "directives" => [],
	    "options" => [],
	    "parent_id" => "",
	    "parent_type" => "",
	    "children" => [],
	},
    ];

    $start_service = $settings{"start_service"} || 0;
    $chroot = $settings{"chroot"} || 1;
    $use_ldap = $settings{"use_ldap"} || 0;
    @allowed_interfaces = @{$settings{"allowed_interfaces"} || []};
    @settings = @{$settings{"settings"} || $default_settings};

    @settings_for_ldap = ();
    $modified = 1;
    $adapt_firewall = 0;
    $write_only = 0;

    if (Mode->autoinst ())
    {
	# set allowed interfaces
	@allowed_interfaces = ();
	foreach my $decl_ref (@settings)
	{
	    my $address = "";
	    if ($decl_ref->{"type"} eq "subnet")
	    {
		$decl_ref->{"id"} =~
		    m/^[ \t]*([^ \t]+)[ \t]+netmask[ \t]+([^ \t]+)[ \t]*$/;
		$address = $1;
	    }
	    elsif ($decl_ref->{"type"} eq "host")
	    {
		foreach my $opt_ref (@{$decl_ref->{"options"} || []})
		{
		    if ($opt_ref->{"key"} eq "fixed-address")
		    {
			$address = $opt_ref->{"value"};
		    }
		}
	    }
	    if (defined ($address) && $address ne "")
	    {
		my @all_ifaces = @{SCR->Dir (".network.section") || []};
		foreach my $i (@all_ifaces)
		{
		    my $iface_info = $self->GetInterfaceInformation ($i);
		    my $network = $iface_info->{"network"} || "";
		    my $netmask = $iface_info->{"netmask"} || "";
		    my $net_cur = IP->ComputeNetwork ($address, $netmask);
		    if ($network eq $net_cur)
		    {
			y2milestone ("Adding interface $i");
			push @allowed_interfaces, $i;
		    }
		};
	    }
	}
	my %ifaces = ();
	foreach my $i (@allowed_interfaces)
	{
	    $ifaces{$i} = 1;
	}
	@allowed_interfaces = sort (keys (%ifaces));
	@original_allowed_interfaces = @allowed_interfaces;

	# Initialize LDAP if needed
	if (ProductFeatures->ui_mode () ne "simple")
	{
	    $self->InitYapiConfigOptions ({"use_ldap" => $use_ldap});
	    $self->LdapInit ([], 1);
	    $self->CleanYapiConfigOptions ();
	}
    }
}

BEGIN{$TYPEINFO{Summary} = ["function",["list","string"],["list","string"]];}
sub Summary {
    my $self = shift;
    my $opt_ref = shift;

    my @ret = ();
    my @opt = @{$opt_ref || []};

    if (0 == scalar (grep (/no_start/, @opt)))
    {
	if ($start_service)
	{
	    # summary string
	    push (@ret, __("The DHCP server is started at boot time"));
	}
	else
	{
	    # summary string
	    push (@ret, __("The DHCP server is not started at boot time"));
	}
    }

    if (0 != scalar (@allowed_interfaces))
    {
	my $allowed_str = join (", ", @allowed_interfaces);
	# summary string, %1 is list of network interfaces
	push (@ret, sformat (__("Listen on: %1"), $allowed_str));

	#FIXME multiple interfaces
	my $interface = $allowed_interfaces[0];
	my $info = $self->GetInterfaceInformation ($interface);
	my $id = $info->{"network"} . " netmask " . $info->{"netmask"};
	if ($self->EntryExists ("subnet", $id))
	{
	    my $directives = $self->GetEntryDirectives ( "subnet", $id );
	    if (defined ($directives))
	    {
		my @directives = @{$directives};
		foreach my $dir_ref (@directives) {
		    my %dir = %{$dir_ref};
		    if ($dir{"key"} eq "range")
		    {
			my $range = $dir{"value"};
			$range =~ s/([0-9])[ \t]+([0-9])/$1 - $2/;
			# summary string, %1 is IP address range
			push (@ret, sformat (__("Dynamic Address Range: %1"),
			    $range));
		    }
		}
            }
	}
    }
    return \@ret;
}

BEGIN { $TYPEINFO{IsConfigurationSimple} = ["function", "boolean"];}
sub IsConfigurationSimple {
    my $self = shift;

    if (ProductFeatures->ui_mode () eq "simple")
    {
	return Boolean (1);
    }
    y2milestone ("Checking how complex configuration is set");

    if (scalar (@allowed_interfaces) > 1)
    {
	return Boolean (0);
    }
    foreach my $decl_ref (@settings) {
	if ($decl_ref->{"type"} eq "")
	{
	    foreach my $opt_ref (@{$decl_ref->{"options"} || []}) {
		my $size = scalar (grep {
		    $_ eq $opt_ref->{"key"}
		} ("domain-name", "domain-name-servers", "routers",
		    "ntp-servers", "lpr-servers", "netbios-name-servers"));
		if ($size == 0)
		{
		    y2milestone ("Non-trivial option of root found");
		    return Boolean (0);
		}
	    }
	    foreach my $dir_ref (@{$decl_ref->{"directives"} || []}) {
		my $size = scalar (grep {
		    $_ eq $dir_ref->{"key"}
		} ("default-lease-time", "ddns-update-style"));
		if ($size == 0)
		{
		    y2milestone ("Non-trivial directive of root found");
		    return Boolean (0);
		}
	    }
	    my $child_count = scalar (@{$decl_ref->{"children"} || []});
	    if ($child_count > 1
		|| ($child_count == 1
		    && $decl_ref->{"children"}[0]{"type"} ne "subnet"))
	    {
		y2milestone ("Child of root that is not subnet or multiple children found");
		return Boolean (0);
	    }
	}
	elsif ($decl_ref->{"type"} eq "subnet")
	{
	    if (scalar (@{$decl_ref->{"options"} || []}) > 0)
	    {
		y2milestone ("Option of subnet fonud");
		return Boolean (0);
	    }
	    foreach my $dir_ref (@{$decl_ref->{"directives"} || []}) {
		my $size = scalar (grep {
		    $_ eq $dir_ref->{"key"}
		} ("default-lease-time", "max-lease-time", "range"));
		if ($size == 0)
		{
		    y2milestone ("Non-trivial directive of subnet found");
		    return Boolean (0);
		}
	    }
	    foreach my $child (@{$decl_ref->{"children"}}) {
		if ($child->{"type"} ne "host")
		{
		    y2milestone ("Child of subnet that is not host found");
		    return Boolean (0);
		}
	    }
	}
	elsif ($decl_ref->{"type"} eq "host")
	{
	    if (scalar (@{$decl_ref->{"options"} || []}) > 0)
	    {
		y2milestone ("Option of host fonud");
		return Boolean (0);
	    }
	    foreach my $dir_ref (@{$decl_ref->{"directives"} || []}) {
		my $size = scalar (grep {
		    $_ eq $dir_ref->{"key"}
		} ("hardware", "fixed-address"));
		if ($size == 0)
		{
		    y2milestone ("Non-trivial directive of root found");
		    return Boolean (0);
		}
	    }
	    my $child_count = scalar (@{$decl_ref->{"children"} || []});
	    if ($child_count > 1)
	    {
		y2milestone ("Child of host found");
		return Boolean (0);
	    }

	}
	else
	{
	    y2milestone ("Declaration with non-trivial type found");
	    return Boolean (0);
	}
    }
    return Boolean (1);
}

##------------------------------------
## More high level functions

BEGIN{$TYPEINFO{AddSubnet} = ["function","boolean","string","string"];}
sub AddSubnet {
    my $self = shift;
    my $subnet = shift;
    my $netmask = shift;

    $modified = 1;
    return $self->CreateEntry ("subnet", "$subnet netmask $netmask", "", "");
}

BEGIN{$TYPEINFO{DeleteSubnet} = ["function","boolean","string","string"];}
sub DeleteSubnet {
    my $self = shift;
    my $subnet = shift;
    my $netmask = shift;

    $modified = 1;
    return $self->DeleteEntry ("subnet", "$subnet netmask $netmask");
}

BEGIN{$TYPEINFO{AddHost} = ["function","boolean","string","string","string"];}
sub AddHost {
    my $self = shift;
    my $fix_addr = shift;
    my $hw_type = shift;
    my $hw_addr = shift;

    my $ret = $self->CreateEntry ("host", "$fix_addr", "", "");

    my @directives = (
	{
	    "key" => "fixed-address",
	    "value" => "$fix_addr",
	},
	{
	    "key" => "hardware",
	    "value" => "$hw_type $hw_addr",
	}
    );
    $ret = $ret && $self->SetEntryDirectives ("host", "$fix_addr", \@directives);

    $modified = 1;
    return Boolean ($ret);
}

BEGIN{$TYPEINFO{DeleteHost} = ["function","boolean","string"];}
sub DeleteHost {
    my $self = shift;
    my $id = shift;

    $modified = 1;
    return $self->DeleteEntry ("host", "$id");
}

BEGIN{$TYPEINFO{SetOption} = ["function", ["list",["map","string","string"]],["list",["map","string","string"]],"string","string"];}
sub SetOption {
    my $self = shift;
    my $options_ref = shift;
    my $key = shift;
    my $value = shift;

    my @options = @{$options_ref};

    if (substr ($key, 0, 7) eq "option ")
    {
	$key = substr ($key, 7);
    }
    if (defined ($value))
    {
	my $found = 0;
	@options = map {
	    my %o = %{$_};
	    if ($o{"key"} eq $key)
	    {
		$o{"value"} = $value;
		$found = 1;
	    }
	   \%o;
	} @options;
	if (! $found)
	{
	    push @options, {
		"key" => $key,
		"value" => $value,
	    };
	}
    }
    else
    {
	@options = grep {
	    my %o = %{$_};
	    $o{"key"} ne $key;
	} @options;
   }
   return \@options;
}

BEGIN{$TYPEINFO{SetGlobalOption} = ["function","boolean","string","string"];}
sub SetGlobalOption {
    my $self = shift;
    my $option = shift;
    my $value = shift;

    my @options = ();
    my $ret = 0;

    if (substr ($option, 0, 7) eq "option ")
    {
	@options = @{$self->GetEntryOptions ("", "") || []};
    }
    else
    {
	@options = @{$self->GetEntryDirectives ("", "") || []};
    }
    @options = @{SetOption (\@options, $option, $value) || []};
    if (substr ($option, 0, 7) eq "option ")
    {
	$ret = $self->SetEntryOptions ("", "", \@options);
    }
    else
    {
	$ret = $self->SetEntryDirectives ("", "", \@options);
    }
    $modified = 1;
    return Boolean ($ret);
}

BEGIN{$TYPEINFO{SetSubnetOption} = ["function","boolean","string","string","string","string"];}
sub SetSubnetOption {
    my $self = shift;
    my $subnet = shift;
    my $netmask = shift;
    my $option = shift;
    my $value = shift;

    my @options = ();
    my $ret = 0;

    if (substr ($option, 0, 7) eq "option ")
    {
	@options = @{$self->GetEntryOptions ("subnet", "") || []};
    }
    else
    {
	@options = @{$self->GetEntryDirectives ("subnet", "") || []};
    }
    @options = @{SetOption (\@options, $option, $value) || []};
    if (substr ($option, 0, 7) eq "option ")
    {
	$ret = $self->SetEntryOptions ("subnet", "", \@options);
    }
    else
    {
	$ret = $self->SetEntryDirectives ("subnet", "", \@options);
    }
    $modified = 1;
    return Boolean ($ret);
}

BEGIN{$TYPEINFO{SetHostOption} = ["function","boolean","string","string","string"];}
sub SetHostOption {
    my $self = shift;
    my $id = shift;
    my $option = shift;
    my $value = shift;

    my @options = ();
    my $ret = 0;

    if (substr ($option, 0, 7) eq "option ")
    {
	@options = @{$self->GetEntryOptions ("host", "$id") || []};
    }
    else
    {
	@options = @{$self->GetEntryDirectives ("host", "$id") || []};
    }
    @options = @{SetOption (\@options, $option, $value) || []};
    if (substr ($option, 0, 7) eq "option ")
    {
	$ret = $self->SetEntryOptions ("host", "$id", \@options);
    }
    else
    {
	$ret = $self->SetEntryDirectives ("host", "$id", \@options);
    }
    $modified = 1;
    return Boolean ($ret);
}

BEGIN { $TYPEINFO{WasConfigured} = [ "function", "boolean" ];}
sub WasConfigured {
    my $self = shift;

    y2milestone ("Already configured: $was_configured");
    return Boolean($was_configured);
}

BEGIN{$TYPEINFO{GetInterfaceInformation}=["function",["map","string","string"],"string"];}
sub GetInterfaceInformation {
    my $self = shift;
    my $interface = shift;

    y2milestone ("Gettign information about interface $interface");
    my %out = %{SCR->Execute (".target.bash_output",
	"/sbin/getcfg-interface $interface") || {}};
    if ($out{"exit"} != 0)
    {
	y2error ("getcfg-interface exited with code $out{\"exit\"}");
	return {};
    }
    if ($out{"stdout"} eq "0")
    {
	y2error ("getcfg-interface returned strange interface \"0\"");
	return {};
    }
    $interface = $out{"stdout"};

    %out = %{SCR->Execute (".target.bash_output",
	"LANG=en_EN /sbin/ifconfig $interface") || {}};
    if ($out{"exit"} != 0)
    {
	y2error ("getcfg-interface exited with code $out{\"exit\"}");
	return {};
    }

    my @lines = split /\n/, $out{"stdout"};
    @lines = grep /inet addr:.*Bcast:.*Mask:.*/, @lines;
    my $line = $lines[0] || "";
    if ($line =~ /inet addr:[ \t]*([0-9\.]+)[ \t]*Bcast:[ \t]*([0-9\.]+)[ \t]*Mask:[ \t]*([0-9\.]+)[ \t]*$/)
    {
	my $ip = $1;
	my $bcast = $2;
	my $netmask = $3;
	return {
	    "ip" => $ip,
	    "bcast" => $bcast,
	    "network" => IP->ComputeNetwork ($ip, $netmask),
	    "netmask" => $netmask,
	    "bits" => Netmask->ToBits ($netmask),
	};
    }
    y2error ("ifconfig didn't return meaningful data about $interface");
    return {};
}

BEGIN { $TYPEINFO{LdapInit} = ["function", "void", ["list", "any"], "boolean"];}
sub LdapInit {
    my $self = shift;
    my $settings_ref = shift;
    my $report_errors = shift;

    $ldap_available = 0;
    $use_ldap = 0;
    my $configured_ldap = 0;

    if (ProductFeatures->ui_mode () eq "simple")
    {
	return;
    }

    #error message
    my $ldap_error_msg = __("Invalid LDAP configuration. Cannot use LDAP.");

    if (Mode->test ())
    {
	return;
    }

    y2milestone ("Initializing LDAP support");

    my @settings = @{$settings_ref};
    my %settings = ();
    foreach my $s_ref (@settings) {
	my $key = $s_ref->{"key"};
	my $value = $s_ref->{"value"};
	$settings{$key} = $value;
    }

    $ldap_port      = "389";
    $ldap_server    = "";
    $base_config_dn = "";
    if ( defined ($settings{"ldap-server"}) and
         defined ($settings{"ldap-base-dn"}))
    {
	if ($settings{"ldap-server"} =~ /^\"(\S+)\"$/)
	{
	    $ldap_server = $1;
	}

	if ($settings{"ldap-base-dn"} =~ /^\"(.+)\"$/)
	{
	    $base_config_dn = $1;
	}

        if ($settings{"ldap-port"} =~ /^(\d+)$/)
	{
	    $ldap_port      = $1 if($1 > 0 && $1 < 65535);
	}

	if ($ldap_server ne "" and $base_config_dn ne "")
	{
	    $configured_ldap = 1;
	}
    }
    y2milestone ("DHCP configured LDAP: $configured_ldap");

    # grab info about the LDAP server
    Ldap->Read ();
    my $ldap_data_ref = Ldap->Export ();

    $use_ldap = $configured_ldap;
    if (defined $yapi_conf{"use_ldap"})
    {
	$use_ldap = $yapi_conf{"use_ldap"};
	y2milestone ("YaPI sepcified to use LDAP: $use_ldap");
    }

    if (! $use_ldap)
    {
	y2milestone ("Not using LDAP");
	return;
    }
    elsif( !$configured_ldap)
    {
	my $server = $ldap_data_ref->{"ldap_server"};
	if (! defined ($server))
	{
	    $server = "";
	}
	my @server_port = split /:/, $server;
	$ldap_server = $server_port[0] || "";
	$ldap_port   = $server_port[1] || "389";

	if($ldap_server eq "")
	{
	    $ldap_server = "localhost";
	}
	if($ldap_port eq "" || $ldap_port == 0)
	{
	    $ldap_port = "389";
	}
    }

    if ($ldap_server eq "")
    {
	$use_ldap = 0;
	y2milestone ("LDAP not configured - can't find server");
	if ($report_errors)
	{
	    Report->Error ($ldap_error_msg); 
	}
	return;
    }

    # connect to the LDAP server
    my %ldap_init = (
	"hostname" => $ldap_server,
	"port"     => $ldap_port,
    );

    $ldap_domain = $ldap_data_ref->{"ldap_domain"} || "";
    if ($ldap_domain eq "")
    {
        $use_ldap = 0;
        y2milestone ("LDAP not configured - can't read LDAP domain");
	if ($report_errors)
	{
	    Report->Error ($ldap_error_msg); 
	}
        return;
    }
    y2milestone ("LDAP main base DN: $ldap_domain");

    # get main configuration DN
    $ldap_config_dn = Ldap->GetMainConfigDN ();
    y2milestone ("Main configuration DN: $ldap_config_dn");
    if (! defined ($ldap_config_dn) || $ldap_config_dn eq "")
    {
	$use_ldap = 0;
	y2milestone ("Main config DN not found");
	if ($report_errors)
	{
	    Report->Error ($ldap_error_msg); 
	}
	return;
    }

    my $ret = SCR->Execute (".ldap", \%ldap_init);
    if ($ret == 0)
    {
	$use_ldap = 0;
	Ldap->LDAPErrorMessage ("init", Ldap->LDAPError ());
	return;
    }

    $ret = SCR->Execute (".ldap.bind", {});
    if ($ret == 0)
    {
	$use_ldap = 0;
	Ldap->LDAPErrorMessage ("bind", Ldap->LDAPError ());
	return;
    }

    if ($base_config_dn eq "")
    {
	# our default/fallback dhcp base dn
	$base_config_dn = 'ou=DHCP,'.$ldap_domain;

	# find suseDhcpConfiguration object
	my %ldap_query = (
	    "base_dn" => $ldap_config_dn,
	    "scope"   => 2,	 # sub tree search
	    "map"     => 1,
	    "filter" => "(objectclass=suseDhcpConfiguration)",
	    "not_found_ok" => 1,
	);

	my %found = %{ SCR->Read (".ldap.search", \%ldap_query) || {} };
	my $dhcp_conf_dn = "cn=defaultDHCP,$ldap_config_dn";
	if (scalar (keys (%found)) > 0)
	{
	    my @keys = sort (keys (%found));
	    $dhcp_conf_dn = $keys[0];
	    %found = %{$found{$dhcp_conf_dn}};
	    # check if base DN for dhcp config is defined
	    my @bases = @{ $found{"susedefaultbase"} || [] };
	    if (@bases > 0)
	    {
		$base_config_dn = $bases[0];
	    }
	}
    }

    if ($use_ldap)
    {
	@settings_for_ldap = @settings;
	@settings_for_ldap = grep {
	    $_->{"key"} =~ /^[ \t]*ldap-.*$/;
	} @settings_for_ldap;

	# now query to find out the servers
	my %ldap_query = (
	    "base_dn" => $base_config_dn,
	    "filter"  => "(&(objectClass=dhcpServer)".
	                 "(|(cn=$dhcp_server)(cn=$dhcp_server_fqdn)))",
	    "scope"   => 2, # scope sub
	    "map"     => 1, # gimme a list (single entry)
	    "not_found_ok" => 1,
	);

	y2milestone("Trying to find our dhcpServer entry: ".$ldap_query{'filter'});
	my %servers = %{ SCR->Read (".ldap.search", \%ldap_query) || {}};
	my @server_dns = sort (keys (%servers));

	$dhcp_server_dn = "";
	if(scalar(@server_dns) > 0)
	{
	    $dhcp_server_dn = $server_dns[0];
	    y2milestone ("Choosing server $dhcp_server_dn");
	    y2milestone ("Using LDAP server $dhcp_server_dn");
	    my %server_entry = %{ $servers{$dhcp_server_dn} };
	    if (scalar (@{$server_entry{"dhcpservicedn"}}) > 1)
	    {
		# error report
		Report->Error (__("Support for multiple dhcpServiceDN not implemented."));
	    }
	    $ldap_dhcp_config_dn = $server_entry{"dhcpservicedn"}[0];
	    if (!(defined ($ldap_dhcp_config_dn) && $ldap_dhcp_config_dn =~ /\S+/))
	    {
		# error report
		Report->Error (__("DHCP service DN is not defined."));
		return 0;
	    }
	}

	if ($dhcp_server_dn eq "")
	{
	    $dhcp_server_dn =  "cn=$dhcp_server,ou=DHCP,$ldap_domain";
	    $ldap_dhcp_config_dn = "cn=config1,$dhcp_server_dn";
	    # will be created while saving
	}

	my $ldap_data_ref = Ldap->Export ();

	# check existence of the main primary ldap config DN
	%ldap_query = (
	    "base_dn" => $ldap_dhcp_config_dn,
	    "filter"  => "(objectClass=dhcpService)",
	    "scope"   => 0, # scope base
	    "map"     => 0, # gimme a list (single entry)
	    "not_found_ok" => 1,
	);

	my @found = @{ SCR->Read (".ldap.search", \%ldap_query) || []};
	if (@found == 0)
	{
	    # will be created while saving
	}
	else
	{
	    my $pri_dn = $found[0]{"dhcpprimarydn"}[0] || "";
	    y2milestone ("Primary DN: $pri_dn");
	    if ($dhcp_server_dn ne $pri_dn)
	    {
		# error report
		Report->Error (__("Support for multiple dhcpServiceDN not implemented."));
	    }
	}
    }
}

BEGIN { $TYPEINFO{LdapPrepareToWrite} = ["function", "boolean"];}
sub LdapPrepareToWrite {
    my $self = shift;

    if (ProductFeatures->ui_mode () eq "simple")
    {
	return;
    }

    my $ldap_data_ref = Ldap->Export ();

    # check if the schema is properly included
    if (DNS->IsHostLocal ($ldap_server))
    {
	y2milestone ("LDAP server is local, checking included schemas");
	LdapServerAccess->AddLdapSchemas (
	    ["/etc/openldap/schema/dhcp.schema"],
	    1
	);
    }
    else
    {
	y2milestone ("LDAP server is remote, not checking if schemas are properl
y included");
    }

    # reconnect to the LDAP server
    my $ret = Ldap->LDAPInit ();
    if ($ret ne "")
    {
	Ldap->LDAPErrorMessage ("init", $ret);
	return 0;
    }

    # login to the LDAP server
    if (defined ($yapi_conf{"ldap_passwd"}))
    {
	my $err = Ldap->LDAPBind ($yapi_conf{"ldap_passwd"});
	Ldap->SetBindPassword ($yapi_conf{"ldap_passwd"});
	if ($err ne "") 
	{
	    Ldap->LDAPErrorMessage ("bind", $err);
	    return 0;
	}
    }
    else
    {
	my $auth_ret = Ldap->LDAPAskAndBind (0);
	Ldap->SetBindPassword ($auth_ret);

	if (! defined ($auth_ret) || $auth_ret eq "")
	{
	    y2milestone ("Authentication canceled");
	    $use_ldap = 0;
	    return;
	}
    }

    Ldap->SetGUI(YaST::YCP::Boolean(0)); 
    if(! Ldap->CheckBaseConfig($ldap_config_dn))
    { 
	Ldap->SetGUI(YaST::YCP::Boolean(1)); 
	Report->Error (sformat (__("Error occurred while creating %1."),
	    $ldap_config_dn));
    } 
    Ldap->SetGUI(YaST::YCP::Boolean(1)); 

    my %ldap_query = ();

    # find suseDhcpConfiguration object
    %ldap_query = (
	"base_dn" => $ldap_config_dn,
	"scope"   => 2,	 # sub tree search
	"map"     => 1,
	"filter" => "(objectclass=suseDhcpConfiguration)",
	"not_found_ok" => 1,
    );

    my %found = %{ SCR->Read (".ldap.search", \%ldap_query) || {} };
    my $dhcp_conf_dn = "cn=defaultDHCP,$ldap_config_dn";
    if (scalar (keys (%found)) == 0)
    {
	y2milestone ("No DHCP configuration defaults found in LDAP, creating it");
	my %ldap_object = (
	    'objectclass'     => [ 'top', 'suseDhcpConfiguration' ],
	    'cn'              => [ 'defaultDHCP' ],
	    'susedefaultbase' => [ $base_config_dn ],
	);
	my %ldap_request = (
	    "dn" => $dhcp_conf_dn
	);
	y2milestone ("Adding DHCP configuration defaults: ".$ldap_request{"dn"});
	my $result = SCR->Write (".ldap.add", \%ldap_request, \%ldap_object);
	if (! $result)
	{
	    # Error report
	    Report->Error (sformat (__("Error occurred while creating %1."),
                                      $dhcp_conf_dn));
	    my $err = SCR->Read (".ldap.error") || {};
	    my $err_descr = Dumper ($err);
	    y2error ("Error descr: $err_descr");

	    $use_ldap = 0;
	    return;
	}
	%found = %ldap_object;
    }
    else
    {
	my @keys = sort (keys (%found));
	$dhcp_conf_dn = $keys[0];
	%found = %{$found{$dhcp_conf_dn}};
    }

    # check if base DN for dhcp config is defined
    my @bases = @{ $found{"susedefaultbase"} || [] };
    if (@bases == 0)
    {
	my %ldap_object = %found;
	$ldap_object{"susedefaultbase"} = [$base_config_dn];
        my %ldap_request = (
	    "dn" => "$dhcp_conf_dn",
	);
	my $result = SCR->Write (".ldap.modify", \%ldap_request, \%ldap_object);
	if (! $result)
	{
	    # error report
	    Report->Error (sformat (__("Error occurred while updating %1."), $dhcp_conf_dn));
	    my $err = SCR->Read (".ldap.error") || {};
	    my $err_descr = Dumper ($err);
	    y2error ("Error descr: $err_descr");

	    $use_ldap = 0;
	    return;
	}
	@bases = ($base_config_dn);
    }

    # query the DHCP organizational unit
    %ldap_query = (
	"base_dn" => $base_config_dn,
	"scope" => 0,
	"map" => 0,
	"not_found_ok" => 1,
    );

    my @dhcps = @{SCR->Read (".ldap.search", \%ldap_query) || []};
    if (@dhcps == 0)
    {
	my %ldap_object = (
	    "objectclass" => [ "top", "organizationalUnit" ],
	    "ou" => [ "DHCP" ],
	);
	my %ldap_request = (
	    "dn" => "$base_config_dn",
	);
	my $result = SCR->Write (".ldap.add",\%ldap_request,\%ldap_object);
	if (! $result)
	{
	    # Error report
	    Report->Error (sformat (__("Error occurred while creating %1."),
		$base_config_dn));
	    my $err = SCR->Read (".ldap.error") || {};
	    my $err_descr = Dumper ($err);
	    y2error ("Error descr: $err_descr");
	    return 0;
	}
    }


    # now query to find out the servers
    %ldap_query = (
	"base_dn" => $base_config_dn,
	"filter"  => "(&(objectClass=dhcpServer)".
	                 "(|(cn=$dhcp_server)(cn=$dhcp_server_fqdn)))",
	"scope"   => 2, # scope sub
	"map"     => 1, # gimme a list (single entry)
	"not_found_ok" => 1,
    );

    y2milestone("Trying to find our dhcpServer entry: ".$ldap_query{'filter'});
    my %servers = %{ SCR->Read (".ldap.search", \%ldap_query) || {}};
    if(scalar(keys (%servers)) == 0)
    {
	y2milestone ("DHCP server not found in LDAP, creating ".
	    $dhcp_server_dn);
	my %server_entry = (
	    "objectclass" => [ "top", "dhcpServer", "dhcpOptions" ],
	    "dhcpservicedn" => [ $ldap_dhcp_config_dn ],
	    "cn" => [ $dhcp_server ],
	);
	my %ldap_request = (
		"dn" => $dhcp_server_dn,
	);
	my $result = SCR->Write (".ldap.add",\%ldap_request,\%server_entry);
	if (! $result)
	{
	   # error report
	    Report->Error (sformat (__("Error occurred while creating cn=%2,ou=DHCP,%1."), $ldap_domain, $dhcp_server));
	    my $err = SCR->Read (".ldap.error") || {};
	    my $err_descr = Dumper ($err);
	    y2error ("Error descr: $err_descr");
	    return 0;
	}
	%servers = %{ SCR->Read (".ldap.search", \%ldap_query) || {}};
    }

    # check existence of the main primary ldap config DN
    %ldap_query = (
	"base_dn" => $ldap_dhcp_config_dn,
	"filter"  => "(objectClass=dhcpService)",
	"scope"   => 0, # scope base
	"map"     => 0, # gimme a list (single entry)
	"not_found_ok" => 1,
    );

    my @found = @{ SCR->Read (".ldap.search", \%ldap_query) || []};
    if (@found == 0)
    {
	my @ldap_config_dn_elements = split (/,\s*/, $ldap_dhcp_config_dn);
	my @cn = split(/=/, shift (@ldap_config_dn_elements));
	my $cn = $cn[1];
	my %ldap_object = ( 
	    "objectclass"   => [ "top", "dhcpService", "dhcpOptions" ],
	    "cn"            => [ $cn ],
	    "dhcpprimarydn" => [ "$dhcp_server_dn" ],
	);
	my %ldap_request = (
	    "dn" => "$ldap_dhcp_config_dn",
	);
	y2milestone ("Creating 'cn=$cn' => $ldap_dhcp_config_dn");
	my $result = SCR->Write (".ldap.add",\%ldap_request,\%ldap_object);
	if (! $result)
	{
	    # error report
	    Report->Error (sformat (__("Error occurred while creating %1."),
		$ldap_dhcp_config_dn));
	    my $err = SCR->Read (".ldap.error") || {};
	    my $err_descr = Dumper ($err);
	    y2error ("Error descr: $err_descr");
	    return 0;
	}
    }


    return 1;
}

BEGIN { $TYPEINFO{LdapStore} = ["function", "void" ]; }
sub LdapStore {
    my $self = shift;

    if (ProductFeatures->ui_mode () eq "simple")
    {
	return 1;
    }

    my $ret = 1;

    if (Mode->test ())
    {
	return 1;
    }

    if ($use_ldap)
    {
	@settings_for_ldap = grep {
	    $_->{"type"} ne "directive"
	    || (
		$_->{"key"} ne "ldap-base-dn"
		&& $_->{"key"} ne "ldap-method"
		&& $_->{"key"} ne "ldap-server"
	    );
	} @settings_for_ldap;
	push @settings_for_ldap, {
	    "type" => "directive",
	    "key" => "ldap-base-dn",
	    "value" => "\"$base_config_dn\"",
	    "comment_before" => "",
	    "comment_after" => "",
	};
	push @settings_for_ldap, {
	    "type" => "directive",
	    "key" => "ldap-method",
	    "value" => "static",
	    "comment_before" => "",
	    "comment_after" => "",
	};
	push @settings_for_ldap, {
	    "type" => "directive",
	    "key" => "ldap-server",
	    "value" => "\"$ldap_server\"",
	    "comment_before" => "",
	    "comment_after" => "",
	};

	my $ret = SCR->Write (".etc.dhcpd_conf", \@settings_for_ldap);
	if (! $ret)
	{
	    # error report
	    Report->Error (__("Error occurred while writing /etc/dhcpd.conf."));
	}
    }
    else
    {

    }

    return $ret;
}

# initialize options passed through the YaPI
BEGIN { $TYPEINFO{InitYapiConfigOptions} = ["function", "void", ["map", "string", "any"]]; }
sub InitYapiConfigOptions {
    my $self = shift;
    my $config_ref = shift;

    %yapi_conf = %{$config_ref || {}};
}

BEGIN { $TYPEINFO{CleanYapiConfigOptions} = ["function", "void"]; }
sub CleanYapiConfigOptions {
    my $self = shift;

    %yapi_conf = ();
}


1;

# EOF
