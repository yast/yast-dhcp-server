#! /usr/bin/perl -w
#
# DhcpServer module written in Perl
#

package DhcpTsigKeys;

use strict;

use ycp;
use YaST::YCP qw(Boolean);
use Data::Dumper;
use Time::localtime;

use Locale::gettext;
use POSIX ();     # Needed for setlocale()

POSIX::setlocale(LC_MESSAGES, "");
textdomain("dhcp-server");

our %TYPEINFO;

# persistent variables

my @tsig_keys = ();

my @new_tsig_keys = ();

my @deleted_tsig_keys = ();

# FIXME this should be defined only once for all modules
#sub _ {
#    return gettext ($_[0]);
#}


YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("Progress");
YaST::YCP::Import ("Report");


BEGIN{$TYPEINFO{ListTSIGKeys}=["function",["list",["map","string","string"]]];}
sub ListTSIGKeys {
    return \@tsig_keys;
}

# FIXME the same function in DNS server component
BEGIN{$TYPEINFO{NormalizeFilename} = ["function", "string", "string"];}
sub NormalizeFilename {
    my $filename = $_[0];

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
    my $filename = $_[0];

    y2milestone ("Reading TSIG file $filename");
    $filename = NormalizeFilename ($filename);
    my $contents = SCR::Read (".target.string", $filename);
    if ($contents =~ /.*key[ \t]+([^ \t}{;]+).* {/)
    {
        return ($1);
    }
    return ();
}

BEGIN{$TYPEINFO{AddTSIGKey}=["function", "boolean", "string"];}
sub AddTSIGKey {
    my $filename = $_[0];

    my @new_keys = AnalyzeTSIGKeyFile ($filename);
    y2milestone ("Reading TSIG file $filename");
    $filename = NormalizeFilename ($filename);
    my $contents = SCR::Read (".target.string", $filename);
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
                DeleteTSIGKey ($new_key);
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
    my $key = $_[0];

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
    return map {
	$_->{"filename"};
    } @new_tsig_keys;
}

BEGIN{$TYPEINFO{ListDeletedKeyIncludes}=["function",["list","any"]];}
sub ListDeletedKeyIncludes {
    return map {
	$_->{"filename"};
    } @deleted_tsig_keys;
}

BEGIN{$TYPEINFO{StoreTSIGKeys}=["function","void",["list",["map","string","string"]]];}
sub StoreTSIGKeys {
    @tsig_keys = @{$_[0]};
}

# EOF
