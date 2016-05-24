#!/usr/bin/env perl

use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Client;
use Data::Dumper;
use YAML::XS qw/Load Dump/;

use strict;
use v5.14;

my $url = qq(http://data-stage.globalchange.gov);

&main;

sub main {

    my $g = Gcis::Client->new(url => $url);

    my $r = load_list();

    my $i = 0;
    for (sort keys %{ $r }) {
        # say " $_ : ";
        my $o = $g->get("/lexicon/omb/agency:bureau/$_") or next;
        $r->{$_} = $o->{uri};
    }
    say Dump($r);
}

sub load_list {

    my $yml = do { local $/; <> };
    my $e = Load($yml);
    my %r;
    for (@{ $e }) {
        $a = $_->{_bureau_code} or next;
        chomp $a;
        $a =~ s/ *$//g;
        $a =~ s/^ *//g;
        $r{$a} = undef;
    }

    return \%r;
}
