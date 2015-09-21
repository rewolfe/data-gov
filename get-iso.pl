#!/usr/bin/env perl

use Gcis::Client;
use Iso;
use YAML::XS qw/Dump Load/;
use Data::Dumper;
use v5.20.1;

my $max_iter = -1;

my $yml = do { local $/; <> };
my $l = Load($yml);
my @m;

my @nasa_org = ('NASA', 'National Aeronautics and Space Administration',);

my @ex = qw(
    C1840-NSIDCV0 
    C179126625-ORNL_DAAC
    C191079401-NSIDC_ECS
    C1000000940-NSIDC_ECS
    C207169865-GSFCS4PA
    C197265171-LPDAAC_ECS
    );
      
my $n;
for (@{ $l }) {
    next unless $_->{_identifier} eq $_, @ex;
    # say " l :\n".Dumper($_);
    my $o = $_->{_poc_org};
    next unless grep $o eq $_, @nasa_org;

    my $p = $_->{_identifier};
    my $s = Iso->new($p);
    my $v = $s->get_meta;
    $s->get_org($v);
    $s->get_id($v);
    push @m, $v;

    $n++;
    next if $max_iter < 0;
    last if $n >= $max_iter;
}
say Dump(\@m);

