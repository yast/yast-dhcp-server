=head1 NAME

YaPI::DHCPD - DHCP server configuration API


=head1 PREFACE

This package is the public YaST2 API to configure the ISC DHCP server


=head1 SYNOPSIS

  use YaPI::DHCPD

$status = StopDhcpService($config)

$status = StartDhcpService($config)

$status = GetDhcpServiceStatus($config)

$ret = AddDeclaration($config,$type,$id,$parent_type,$parent_id)

$ret = DeleteDeclaration($config,$type,$id)

$parent = GetDeclarationParent($config,$type,$id)

$ret = SetDeclarationParent($config,$type,$id,$new_parent_type,$new_parent_id)

$children = GetChildrenOfDeclaration($config,$type,$id)

$options = GetDeclarationOptions($config,$type,$id)

$ret = SetDeclarationOptions($config,$type,$id,$options)

$directives = GetDeclarationDirectives($config,$type,$id)

$ret = SetDeclarationDirectives($config,$type,$id,$directives)

$exists = ExistsDeclaration($config,$type,$id)


The C<$config> parameter is always a refernece to a hash, that contains various
configuration options. Currently following keys are supported:

C<"use_ldap">
 says if settings should be written/read to LDAP or not. Possible values are
 1 (use LDAP if configured properly) or 0 (don't use LDAP).
 If not specified, mode is detected automatically.

C<"ldap_passwd">
 holds the LDAP password needed for authentication against the LDAP server.

=head1 DESCRIPTION

=over 2

=cut

package YaPI::DHCPD;
use YaST::YCP;
YaST::YCP::Import ("DhcpServer");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("Progress");

#if(not defined do("YaPI.inc")) {
#    die "'$!' Can not include YaPI.inc";
#}

#######################################################
# temoprary solution end
#######################################################
our $VERSION='1.0.0';
our @CAPABILITIES = ('SLES9');
our %TYPEINFO;

use strict;
use Errno qw(ENOENT);

#######################################################
# default and vhost API start
#######################################################

=item *
C<$status StopDhcpService ($config);>

Immediatelly stops the DHCP service. Returns nonzero if operation succeeded,
zero if operation failed.

EXAMPLE:

  my $status = StopDhcpService ({});
  if ($status == 0)
  {
    print "Stopping DHCP server failed";
  }
  else
  {
    print "Stopping DHCP server succeeded";
  }

=cut

BEGIN{$TYPEINFO{StopDhcpService} = ["function", "boolean", ["map", "string", "any"]];}
sub StopDhcpService {
    my $self = shift;
    my $config_options = shift;

    return 0 == SCR->Execute (".target.bash",
	"/etc/init.d/dhcpd stop");
}

=item *
C<$status StartDhcpService ($config);>

Immediatelly starts the DHCP service. Returns nonzero if operation succeeded,
zero if operation failed.

EXAMPLE:

  my $status = StartDhcpService ({});
  if ($status == 0)
  {
    print "Starting DHCP server failed";
  }
  else
  {
    print "Starting DHCP server succeeded";
  }

=cut

BEGIN{$TYPEINFO{StartDhcpService} = ["function", "boolean", ["map", "string", "any"]];}
sub StartDhcpService {
    my $self = shift;
    my $config_options = shift;

    return 0 == SCR->Execute (".target.bash",
	"/etc/init.d/dhcpd restart");
}

=item *
C<$status GetDhcpServiceStatus ($config);>

Check if DHCP service is running. Returns nonzero if service is running,
zero otherwise.

EXAMPLE:

  my $status = GetDhcpServiceStatus ({});
  if ($status == 0)
  {
    print "DHCP server is not running";
  }
  else
  {
    print "DHCP server is running";
  }

=cut

BEGIN{$TYPEINFO{GetDhcpServiceStatus} = ["function", "boolean", ["map", "string", "any"]];}
sub GetDhcpServiceStatus {
    my $self = shift;
    my $config_options = shift;

    return 0 == SCR->Execute (".target.bash",
	"/etc/init.d/dhcpd status") ? 1 : 0;
}

=item *
C<$ret = AddDeclaration ($config, $type, $id, $parent_type, $parent_id);>

Add a new empty DHCP declaration. $type is one of subnet, host, group, pool,
shared-network. $id is identification of the declaration (eg. host name for
the host, $address netmask $netmask for subnet declaration. $parent_type and
$parent_id specify the declaration within that the new declaration shall
be created.

Returns nonzero on success, zero on fail.

EXAMPLE:

  my $type = "host";
  my $id = "client";
  my $ret = AddDeclaration ({}, $type, $id, "", "");
  
This creates a new host on the top level of the configuration file (not within
any network or group)

=cut

BEGIN{$TYPEINFO{AddDeclaration} = ["function", "boolean", ["map", "string", "any"], "string", "string", "string", "string"];}
sub AddDeclaration {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;
    my $parent_type = shift;
    my $parent_id = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);
    
    Progress::off ();
    my $ret = DhcpServer->Read ();
    $ret = $ret && DhcpServer->CreateEntry ($type, $id, $parent_type, $parent_id);
    $ret = $ret && DhcpServer->Write ();
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $ret;
}

=item *
C<$ret = DeleteDeclaration ($config, $type, $id);>

Deletes specified declaration including its whole subtree.

Returns nonzero on success, zero on fail.

EXAMPLE:

  my $type = "host";
  my $id = "client";
  my $ret = DeleteDeclaration ({}, $type, $id);

This deletes the host created in the example of the AddDeclaration function

=cut

BEGIN{$TYPEINFO{DeleteDeclaration} = ["function", "boolean", ["map", "string", "any"], "string", "string"];}
sub DeleteDeclaration {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);

    Progress::off ();
    my $ret = DhcpServer->Read ();
    $ret = $ret && DhcpServer->DeleteEntry ($type, $id);
    $ret = $ret && DhcpServer->Write ();
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $ret;
}

=item *
C<$parent = GetDeclarationParent ($config, $type, $id);>

Returns the parent of specified declaration. It is returned as a hash with keys
"type" and "id".

Returns the specification of the parent or undef if the specified declaration
was not found.

EXAMPLE:

  my $type = "host";
  my $id = "client";
  my $parent = GetDeclarationParent ({}, $type, $id);
  if (! defined ($parent))
  {
    print "Specified declaration not found"
  }
  else
  {
    my $par_type =  $parent->{"type"};
    my $par_id = $parent->{"id"};
    print "Parent type: $par_type";
    print "Parent id: $par_id;
  }

=cut

BEGIN{$TYPEINFO{GetDeclarationParent} = ["function", ["map", "string", "string"], ["map", "string", "any"], "string", "string"];}
sub GetDeclarationParent {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);

    Progress::off ();
    my $ret = DhcpServer->Read ();
    my $parent = undef;
    if ($ret)
    {
	$parent = DhcpServer->GetEntryParent ($type, $id);
    }
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $parent;
}

=item *
C<$ret = SetDeclarationParent ($config, $type, $id, $new_parent_type, $new_parent_id);>

Sets specified parent to the specified declaration (moves it in the tree). The declaration is moved with its complete subtree.

Returns nonzero on success, zero on fail.

EXAMPLE:

  my $type = "host";
  my $id = "client";
  my $ret = SetDeclarationParent ({}, $type, $id, "", "");

Moves the host declaration from the ssubnet it resides in to the top level.

=cut

BEGIN{$TYPEINFO{SetDeclarationParent} = ["function", "boolean", ["map", "string", "any"], "string", "string", "string", "string"];}
sub SetDeclarationParent {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;
    my $new_par_type = shift;
    my $new_par_id = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);

    Progress::off ();
    my $ret = DhcpServer->Read ();
    $ret = $ret && DhcpServer->SetEntryParent ($type, $id, $new_par_type, $new_par_id);
    $ret = $ret && DhcpServer->Write ();
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $ret;
}

=item *
C<$children = GetChildrenOfDeclaration ($config, $type, $id);>

Get all children of a declaration.

Returns a list of hashes with keys "type" and "id" and appropriate values on
success. On fail, returns undef.

EXAMPLE:

  my $children = GetChildrenOfDeclaration ({}, "subnet", "192.168.0.0 netmask 255.255.255.0");
  if (! defined ($children))
  {
    print "Specified declaration not found";
  }
  else
  {
    foreach my $child (@{$children}) {
      my $type = $child->{"type"};
      my $id = $child->{"id"};
      print "Have child $type $id";
    }
  }

=cut

BEGIN{$TYPEINFO{GetChildrenOfDeclaration} = ["function", ["list", ["map", "string", "string"]], ["map", "string", "any"], "string", "string"];}
sub GetChildrenOfDeclaration {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);

    Progress::off ();
    my $ret = DhcpServer->Read ();
    my $children = undef;
    if ($ret)
    {
	$children = DhcpServer->GetChildrenOfEntry ($type, $id);
    }
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $children;
}

=item *
C<$options = GetDeclarationOptions ($config, $type, $id);>

Get all options of the specified declaration.

Returns all options of specified declaration as a list of hashes with keys
"key" and "value" and appropriate values on success. On fail, returns undef.

EXAMPLE:

  my $options = GetDeclarationOptions ({}, "subnet", "192.168.0.0 netmask 255.255.255.0");
  if (! defined ($options))
  {
    print "Specified declaration not found";
  }
  else
  {
    foreach my $option (@{$options}) {
      my $key = $option->{"key"};
      my $value = $option->{"value"};
      print "Have option $key with value $value";
    }
  }

Prints all options adjusted to tbe specified declaration.

=cut

BEGIN{$TYPEINFO{GetDeclarationOptions} = ["function", ["list", ["map", "string", "string"]], ["map", "string", "any"], "string", "string"];}
sub GetDeclarationOptions {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);

    Progress::off ();
    my $ret = DhcpServer->Read ();
    my $options = undef;
    if ($ret)
    {
	$options = DhcpServer->GetEntryOptions ($type, $id);
    }
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $options;
}

=item *
C<$ret = SetDeclarationOptions ({}, $config, $type, $id, $options);>

Sets all options of specified declaration. The options argument has the same
structure as return value of the GetDeclarationOptions function.

Returns nonzero on success, zero on fail.

EXAMPLE:

  my $options = [
    {
      "key" => "domain-name-servers",
      "value" => "ns1.internal.example.org ns2.internal.example.org",
    },
    {
      "key" => "domain-name",
      "value" => "\"internal.example.org\"",
    },
  ]
  $success = SetDeclarationOptions ("host", "client", $options);

Sets specified options to the specified declaration.

=cut

BEGIN{$TYPEINFO{SetDeclarationOptions} = ["function", "boolean", ["map", "string", "any"], "string", "string", ["list", ["map", "string", "string"]]];}
sub SetDeclarationOptions {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;
    my $options = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);

    Progress::off ();
    my $ret = DhcpServer->Read ();
    $ret = $ret && DhcpServer->SetEntryOptions ($type, $id, $options);
    $ret = $ret && DhcpServer->Write ();
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $ret;
}

=item *
C<$directives = GetDeclarationDirectives ($config, $type, $id);>

Get all directives of the specified declaration.

Returns all directives of specified declaration as a list of hashes with keys
"key" and "value" and appropriate values on success. On fail, returns undef.

EXAMPLE:

  my $directives = GetDeclarationDirectives ({}, "subnet", "192.168.0.0 netmask 255.255.255.0");
  if (! defined ($directives))
  {
    print "Specified declaration not found";
  }
  else
  {
    foreach my $directive (@{$directives}) {
      my $key = $option->{"key"};
      my $value = $option->{"value"};
      print "Have directive $key with value $value";
    }
  }

Prints all directives adjusted to tbe specified declaration.

=cut

BEGIN{$TYPEINFO{GetDeclarationDirectives} = ["function", ["list", ["map", "string", "string"]], ["map", "string", "any"], "string", "string"];}
sub GetDeclarationDirectives {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);

    Progress::off ();
    my $ret = DhcpServer->Read ();
    my $directives = undef;
    if ($ret)
    {
	$directives = DhcpServer->GetEntryDirectives ($type, $id);
    }
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $directives;
}

=item *
C<$ret = SetDeclarationDirectives ($config, $type, $id, $directives);>

Sets all directives of specified declaration. The directives argument has the same
structure as return value of the GetDeclarationDirectives function.

Returns nonzero on success, zero on fail.

EXAMPLE:

  my $directives = [
    {
      "key" => "default-lease-time",
      "value" => "600",
    },
    {
      "key" => "max-lease-time",
      "value" => "7200",
    },
  ]
  $success = SetDeclarationDirectives ({}, "host", "client", $directives);

Sets specified directives to the specified declaration.

=cut

BEGIN{$TYPEINFO{SetDeclarationDirectives} = ["function", "boolean", ["map", "string", "any"], "string", "string", ["list", ["map", "string", "string"]]];}
sub SetDeclarationDirectives {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;
    my $directives = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);

    Progress::off ();
    my $ret = DhcpServer->Read ();
    $ret = $ret && DhcpServer->SetEntryDirectives ($type, $id, $directives);
    $ret = $ret && DhcpServer->Write ();
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $ret;
}



=item *
C<$exists = ExistsDeclaration ($config, $type, $id);>

Checks if specified declaration exists.

Returns nonzero if declaration found, zero otherwise.

EXAMPLE:

  my $exists = ExistsDeclaration ({}, "host", "client");
  if ($exists)
  {
    print "Host found";
  }
  else
  {
    print "Host not found";
  }

Checks if specified host has an entry in the configuration of DHCP server.

=cut



BEGIN{$TYPEINFO{ExistsDeclaration} = ["function", "boolean", ["map", "string", "any"], "string", "string"];}
sub ExistsDeclaration {
    my $self = shift;
    my $config_options = shift;
    my $type = shift;
    my $id = shift;

    DhcpServer->InitYapiConfigOptions ($config_options);

    Progress::off ();
    my $ret = DhcpServer->Read ();
    $ret = $ret && DhcpServer->ExistsEntry ($type, $id);
    Progress::on ();

    DhcpServer->CleanYapiConfigOptions ();

    return $ret;
}


1;
