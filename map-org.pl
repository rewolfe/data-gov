#!/usr/bin/env perl

use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Client;
use Data::Dumper;
use YAML::XS qw/Dump Load/;

use strict;
use v5.14;

my $url = qq(http://data.globalchange.gov);

&main;

sub main {

    my $g = Gcis::Client->new(url => $url);

    my @d;
    my $r = load_list();

    my $i = 0;
    for (sort keys %$r) {
        my $v = $r->{$_};
        my $s = strip($_);
        $v->{$_} = undef for keys %$s;
        if (keys %$s == 2) {
           my @k = keys %$s;
           my $b = "$k[0]-$k[1]";
           $v->{$b} = undef;
           $b = "$k[1]-$k[0]";
           $v->{$b} = undef;
        }
        my $bc;
        for (keys %$v) {
            my $o;
            if ($_ =~ /\d\d\d:\d\d/) {
                $o = $g->get("/lexicon/omb/agency:bureau/$_") or next;
                $v->{$_} = $o->{uri};
                $bc = $_;
                next;
            }
            $o = $g->get('/lexicon/govman/Agency/'.(uc $_));
            if ($o->{uri}) {
                $v->{$_} = $o->{uri};
                next;
            }
            $o = $g->get("/organization/$_") or next;
            $v->{$_} = $o->{uri};
        }
        $v->{_name} = $_;
        my $f;
        for (keys %$s) {
            next unless $v->{$_};
            $f = $v->{$_};
            last;
        }
        my $b = $v->{$bc};

        my $u;
        my $c;
        if (keys %$s == 1) {
            if ($f) {
                $u = $f;
                if ($b  &&  $b ne $f) {
                    $u = undef;
                    $c = $f;
                }
            } elsif ($b) {
                $c = $b;
            }
        } elsif (keys %$s > 1) {
            $c = $f ? $f : $b;
        }

        $v->{_uri} = $u;
        $v->{_check_uri} = $c if $c;

        push @d, $v;
        # last if $i >= 10;
        $i++;
    }
    say Dump(\@d);
}

sub load_list {

    my $yml = do { local $/; <> };
    my $e = Load($yml);
    my %r;
    for (@$e) {
        # say " e :\n".Dumper($_);
        $a = $_->{_poc_org};
        chomp $a;
        $a =~ s/ *$//g;
        $a =~ s/^ *//g;
        $a =~ s/^'*//g;
        $a =~ s/'*$//g;
        $r{$a} = undef;

        $b = $_->{_ckan}->{bureauCode} or next;
        chomp $b;
        $b =~ s/ *$//g;
        $b =~ s/^ *//g;
        $r{$a}->{$b} = undef;
    }

    return \%r;
}

sub strip {
    my $s = shift;

    chomp $s;
    $s = lc $s;
    $s =~ s/ +/ /g;
    $s =~ s/[,'] */|/g;
    $s =~ s/ *[\/:>]+ */|/g;
    $s =~ s/ - /|/g;
    $s =~ s/ *& */ /g;
    $s =~ s/u\. *s\. /us /g;
    $s =~ s/united states /us /g;
    $s =~ s/dept\. /department /g;
    $s =~ s/department /us department /g;
    $s =~ s/us us /us /g;
    $s =~ s/u\. /university /g;
    $s =~ s/[\(\)]/|/g;
    $s =~ s/ *\|+ */\|/g;
    $s =~ s/^ *\|+//;
    $s =~ s/\|+ *$//;
    $s =~ s/ (and|of|for) / /g;
    $s =~ s/ /-/g;

    return undef unless $s;

    my %m;
    $m{$_} = undef for split /\|/, $s;

    return \%m;
}
