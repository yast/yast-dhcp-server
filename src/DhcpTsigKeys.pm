#! /usr/bin/perl -w
#
# DhcpServer module written in Perl
#

package DhcpTsigKeys;

use strict;

use YaST::YCP qw(:LOGGING Boolean);
use Data::Dumper;
use Time::localtime;

use YaPI;
textdomain("dhcp-server");

our %TYPEINFO;

# persistent variables

my @tsig_keys = ();

my @new_tsig_keys = ();

my @deleted_tsig_keys = ();

YaST::YCP::Import ("SCR");


BEGIN{$TYPEINFO{ListTSIGKeys}=["function",["list",["map","string","string"]]];}
sub ListTSIGKeys {
    return \@tsig_keys;
}

# FIXME the same function in DNS server component
BEGIN{$TYPEINFO{NormalizeFilename} = ["function", "string", "string"];}
sub NormalizeFilename {
    my $self = shift;
    my $filename = shift;

    while ($filename ne "" && (substr ($filename, 0, 1) eq " "
        || substr ($filename, 0, 1) eq "\""))
    {
        $filename = substr ($filename, 1);
    }
    while ($filename ne ""
        && (substr ($filename, length ($filename) - 1, 1) eq " "
            || substr ($filename, length ($filename) - 1, 1) eq "\""))
    {
        $filename = substr ($filename, 0, length ($filename) - 1);
    }
    return $filename;
}

# FIXME multiple keys in one file
# FIXME the same function in DNS server component
BEGIN{$TYPEINFO{AnalyzeTSIGKeyFile}=["function",["list","string"],"string"];}
sub AnalyzeTSIGKeyFile {
    my $self = shift;
    my $filename = shift;

    y2milestone ("Reading TSIG file $filename");
    $filename = $self->NormalizeFilename ($filename);
    my $contents = SCR->Read (".target.string", $filename);
    if (! defined ($contents))
    {
	return [];
    }
    if ($contents =~ /.*key[ \t]+([^ \t}{;]+).* {/)
    {
        return [$1];
    }
    return [];
}

BEGIN{$TYPEINFO{AddTSIGKey}=["function", "boolean", "string"];}
sub AddTSIGKey {
    my $self = shift;
    my $filename = shift;

    my @new_keys = @{$self->AnalyzeTSIGKeyFile ($filename)};
    y2milestone ("Reading TSIG file $filename");
    $filename = $self->NormalizeFilename ($filename);
    @tsig_keys = grep {
	$_->{"filename"} ne $filename;
    } @tsig_keys;
    my $contents = SCR->Read (".target.string", $filename);
    if (0 != @new_keys)
    {
        foreach my $new_key (@new_keys) {
            y2milestone ("Having key $new_key, file $filename");
            # remove the key if already exists
            my @current_keys = grep {
                $_->{"key"} eq $new_key;
            } @tsig_keys;
            if (@current_keys > 0)
            {
                $self->DeleteTSIGKey ($new_key);
            }
            #now add new one
            my %new_include = (
                "filename" => $filename,
                "key" => $new_key,
            );
            push @tsig_keys, \%new_include;
            push @new_tsig_keys, \%new_include;
        }
        return Boolean (1);
    }
    return Boolean (0);
}

BEGIN{$TYPEINFO{DeleteTSIGKey}=["function", "boolean", "string"];}
sub DeleteTSIGKey {
    my $self = shift;
    my $key = shift;

    y2milestone ("Removing TSIG key $key");
    #add it to deleted list
    my @current_keys = grep {
        $_->{"key"} eq $key;
    } @tsig_keys;
    if (@current_keys == 0)
    {
        y2error ("Key not found");
        return Boolean(0);
    }
    foreach my $k (@current_keys) {
        push @deleted_tsig_keys, $k;
    }
    #remove it from current list
    @new_tsig_keys = grep {
        $_->{"key"} ne $key;
    } @new_tsig_keys;
    @tsig_keys = grep {
        $_->{"key"} ne $key;
    } @tsig_keys;

    return Boolean (1);
}

BEGIN{$TYPEINFO{ListNewKeyIncludes}=["function", ["list","any"]];}
sub ListNewKeyIncludes {
    my $self = shift;
    my @ret = map {
	$_->{"filename"};
    } @new_tsig_keys;
    return \@ret;
}

BEGIN{$TYPEINFO{ListDeletedKeyIncludes}=["function",["list","any"]];}
sub ListDeletedKeyIncludes {
    my $self = shift;
    my @ret = map {
	$_->{"filename"};
    } @deleted_tsig_keys;
    return \@ret;
}

BEGIN{$TYPEINFO{StoreTSIGKeys}=["function","void",["list",["map","string","string"]]];}
sub StoreTSIGKeys {
    my $self = shift;
    my $tsig_keys_ref = shift;

    @tsig_keys = @{$tsig_keys_ref};
    return;
}

# EOF
