#!/usr/bin/env perl

use Gcis::Client;
use Iso;
use YAML::XS qw/Dump Load/;
use Data::Dumper;
use v5.18.1;

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

my %org_map = (
    GESDISC => 'goddard-earth-sciences-data-information-services-center',
    LAADS => 'level1-atmosphere-archive-distribution-system',
    LaRC => 'atmospheric-science-data-center',
    LPDAAC => 'land-processes-distributed-active-archive-center',
    NSIDC => 'national-snow-ice-data-center-distributed-active-archive-center',
    ORNL_DAAC => 'oak-ridge-national-laboratory-distributed-active-archive-center',
    SEDAC => 'socioeconomic-data-applications-center',
    );

my %id_map = (
    GESDISC => 'gesdisc',
    LAADS => 'laads',
    LaRC => 'asdc',
    LPDAAC => 'lpdaac',
    NSIDC => 'nsidcdaac',
    ORNL_DAAC => 'ornldaac',
    SEDAC => 'sedac',
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
    get_org($v);
    get_id($v);
    get_url($v);
    push @m, $v;

    $n++;
    next if $max_iter < 0;
    last if $n >= $max_iter;
}
say Dump(\@m);

sub get_org {
    my $p = shift or return;

    my $v = $p->{_poc_org} or return;
    my $o = $org_map{$v} or return;
    $p->{_organization} = "/organization/$o";
    return;
}

sub get_id {
    my $p = shift or return;

    my $v = $p->{name} or return;
    my $o = $p->{_poc_org} or return;
    return unless $org_map{$o};
    return unless $v =~ / *> */;

    my ($i, $n) = split / *> */, $v;

    $p->{_echo_id} = $p->{native_id};
    $p->{native_id} = $p->{_id}->{DIFEntryId};
    if ($o eq 'NSIDC') {
        if ($i =~ /-\d+$/) {
            $i =~ s/.*-(\d+)$/$1/;
        } else {
            if (!$p->{native_id}) {
                $p->{native_id} = $i;
            }
            $i = lc $i;
        }
    } elsif ($o eq 'ORNL_DAAC') {
        $p->{doi} = ($i =~ s/^doi://r);
        $i =~ s/.*\/(\d+)$/$1/;
    } elsif ($o eq 'GESDISC') {
        $i = lc ($p->{_id}->{DIFEntryId} =~ s/^GES_DISC_//r);
    } elsif (grep $o eq $_, qw(LPDAAC LAADS)) {
        $i = $p->{native_id} ? lc $p->{native_id} : lc $i;
    }
    my $dn = 'identifier_product_doi - Digital object identifier that uniquely identifies this data product';
    my $d = $p->{_id}->{$dn};
    $p->{doi} = $d if $d;
    $p->{identifier} = 'nasa-'.$id_map{$o}.'-'.$i;
    $p->{name} = $n;
    $p->{uri} = "/dataset/$p->{identifier}";


    return;
}

sub get_url {
    my $p = shift or return;

    my $v = $p->{_poc_org} or return;
    my $o = $org_map{$v} or return;
    if ($o eq 'NSIDC') {
        $p->{native_id} or return;
        $p->{url} = 'http://nsidc.org/data/'.$p->{native_id};
        return;
    } 
    if ($o eq 'ORNL_DAAC') {
        my $i = $p->{identifier} or return;
        $i =~ s/nasa-ornldaac-//;
        $p->{url} = 'http://daac.ornl.gov/cgi-bin/dsviewer.pl?ds_id='.$i;
        return;
    }
    return;
}
