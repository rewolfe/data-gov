#!/usr/bin/env perl

use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Client;
use Data::Dumper;
use YAML::XS qw/Dump Load/;

use strict;
use v5.14;

my $n_max = -1;
my $update = 1;
# my $url = qq(https://data.gcis-dev-front.joss.ucar.edu);
my $url = qq(https://data-stage.globalchange.gov);

&main;

sub main {

    my $g = $update ? Gcis::Client->connect(url => $url)
                    : Gcis::Client->new(url => $url);

    my @d;
    my $e = load_list();
    my $r;

    my $i = 0;
    for (@{ $e }) {
        my @n = split /\t/, $_->{_name};
        say " $i - $n[0]";
        get_stat($_);
        put_alias($g, $_);

        $i++;
        last if $i >= $n_max  &&  $n_max > 0;
    }

    exit;
}

sub load_list {
    my $yml = do { local $/; <> };
    my $e = Load($yml);

    return \@$e;
}

sub get_stat {
    my $r = shift;
    my @s;
    my @g;
    for (keys %$r) {
        my @v = split /\t/, $r->{$_};
        my $n = @v;
        next if $n <= 1;
        $r->{$_} = $v[0];
        say " warning - more than 3 items : $n" if $n > 3;
        push @s, lc $v[1];
        push @g, $v[2];
    }
    # say " s :".Dumper(@s);
    # say " u :".Dumper(@g);
    $r->{status} = \@s;
    $r->{gcid} = \@g;
    
    return;
}

sub put_alias {
    my ($c, $r) = @_;

    my $sa = $_->{status};

    my $n_s = @$sa;
    if ($n_s != 1) {
        say " warning - not exactly one status : $n_s";
        return;
    }

    my $ga = $_->{gcid};
    my $n_g = @$ga;
    if ($n_g != 1) {
        say " warning - not exactly one gcid : $n_g";
        return;
    }

    my $s = $sa->[0];
    my $g = $ga->[0];

    if (!grep $s eq $_, qw(added updated ok)) {
        say " warning - not a normal status : $s";
        return;
    }
    say "   s : $s";

    if (!$g) {
       say " warning - null gcid";
       return;
    }

    $g =~ s/http(s|):\/\/.*gov//;
    say "   g : $g";
    my $v = $c->get($g) or do {
        say " warning - not a valid gcid : $g";
        return;
    };
    say "   v.name : $v->{name}";

    my $o = "Organization";
    my $p = "/lexicon/datagov";
    my $n = $_->{_name} or do {
        say " warning - term is null";
        return;
    };
    # say "   n : $n";

    my $v = $c->get("$p/$o/$n");
    # say " v :".Dumper($v);
    if ($v) {
        my $u = $v->{uri};
        say "   term exists : $u";
        if ($u ne $g) {
            " warning - gcid is different : $u";
        }
        return;

    }
    if (!$update) {
        say "   would add term : $n";
        return;
    }

    say "   adding term : $n";
    my $v = {
        term => $n,
        context => $o,
        gcid => $g,
        };
    $c->post("$p/term/new", $v) or do {
        say " warning - error posting new term";
        return;
    };

    return;
}
