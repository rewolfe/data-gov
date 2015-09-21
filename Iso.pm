package Iso;

use v5.20.1;
use Mojo::UserAgent;
use Data::Dumper;

my $m_id = 'gmd\:identificationInfo > gmd\:MD_DataIdentification > ';
my $m_di = 'gmd\:distributionInfo > gmd\:MD_Distribution > 
            gmd\:distributor > gmd\:MD_Distributor > ';
my $m_cs = 'gco\:CharacterString';
my $m_ci = $m_id.'gmd\:citation > gmd\:CI_Citation > ';
my $m_ex = $m_id.'gmd\:extent > gmd\:EX_Extent > ';
my $m_gx = $m_ex.'gmd\:geographicElement > gmd\:EX_GeographicBoundingBox > ';
my $m_dc = 'gco\:Decimal';
my $m_tx = $m_ex.'gmd\:temporalElement > gmd\:EX_TemporalExtent >
           gmd\:extent > gml\:TimePeriod > ';
my $m_ai = 'gmi\:acquisitionInformation > gmi\:MI_AcquisitionInformation > ';
my $m_hi = 'gmi\:identifier > gmd\:MD_Identifier >% 
            gmd\:code > '.$m_cs.' >% gmd\:description > '.$m_cs;

my $map_iso = {
    # identifier   => 'header identifier',
    _id          => $m_ci.'gmd\:identifier >@ gmd\:MD_Identifier >% 
                           gmd\:description > '.$m_cs.' >% 
                           gmd\:code > '.$m_cs, 
    native_id    => 'gmd\:fileIdentifier > '.$m_cs,
    _name        => $m_ci.'gmd\:title > '.$m_cs,
    description  => $m_id.'gmd\:abstract > '.$m_cs,
    _url1        => $m_ci.'gmd\:citedResponsibleParty >
                    gmd\:CI_ResponsibleParty > gmd\:contactInfo >
                    gmd\:CI_Contact > gmd\:onlineResource >
                    gmd\:CI_OnlineResource > gmd\:linkage > gmd\:URL',
    _url2        => $m_di.'gmd\:distributorTransferOptions > 
                    gmd\:MD_DigitalTransferOptions > gmd\:onLine > 
                    gmd\:CI_OnlineResource > gmd\:linkage > gmd\:URL',
    # doi          => 'Data_Set_Citation',
    lat_min      => $m_gx.'gmd\:southBoundLatitude > '.$m_dc,
    lat_max      => $m_gx.'gmd\:northBoundLatitude > '.$m_dc,
    lon_min      => $m_gx.'gmd\:westBoundLongitude > '.$m_dc,
    lon_max      => $m_gx.'gmd\:eastBoundLongitude > '.$m_dc,
    start_time   => $m_tx.'gml\:beginPosition',
    end_time     => $m_tx.'gml\:endPosition',
    release_dt   => $m_ci.'gmd\:date > gmd\:CI_Date > gmd\:date > gco\:Date',
    _poc_org     => $m_id.'gmd\:pointOfContact > gmd\:CI_ResponsibleParty >
                           gmd\:organisationName > '.$m_cs,
    _instrument  => $m_ai.'gmi\:instrument >@ gmi\:MI_Instrument > '.$m_hi, 
    _platform    => $m_ai.'gmi\:platform >@ gmi\:MI_Platform > '.$m_hi, 
    _instrument_eos => $m_ai.'gmi\:instrument >@ eos\:EOS_Instrument > '.$m_hi,
    _platform_eos => $m_ai.'gmi\:platform >@ eos\:EOS_Platform > '.$m_hi,
    };

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

sub new {
    my $class = shift;
    my $id = shift;

    my $ua = Mojo::UserAgent->new;
    $ua->max_redirects(3);

    my $u = "http://reverb.echo.nasa.gov/reverb/query.iso19115?catalog_id=".$id."&id=".$id;

    my $s;
    $s->{id} = $id;
    $s->{dom} = $ua->get($u)->res->dom or do {
         say " error - getting iso metadata for : $id";
         return undef;
    };
    bless $s, $class;
    return $s;
};

sub set_dom {
    my $class = shift;
    my $dom = shift;
    my $id = shift;

    my $s;
    $s->{id} = $id;
    $s->{dom} = $dom;
    bless $s, $class;
    return $s;
};

sub get_meta {
    my $s = shift;

    my %m;
    for (keys %$map_iso) {
       my $f = $map_iso->{$_};
       if ($f =~ / +>@ +/) {
           my $a = $s->_get_array($s->{dom}, $f) or next;
           $m{$_} = $a;
           next;
       }
       if ($f =~ / +>% +/) {
           my $h = $s->_get_hash($s->{dom}, $f) or next;
           $m{$_} = $h;
           next;
       }
       my $v = $s->{dom}->at($f) or next;
       next unless $v->text;
       $m{$_} = $v->text;
    }

    $m{_identifier} = $s->{id};
    if ($m{_url1}) {
        $m{url} = $m{_url1};
    } elsif ($m{_url2}) {
        $m{url} = $m{_url2};
    }

    return \%m;
}

sub _get_array {
    my $s = shift;
    my $d = shift;
    my $f = shift;

    my ($a, $l) = split ' >@ ', $f;
    my @v = $d->find($a)->each or return undef;

    if ($l =~ / +>% +/) {
        my %z;
        for (@v) {
            my $h = $s->_get_hash($_, $l) or next;
            $z{$_} = $h->{$_} for keys %$h;;
        }
        return %z ? \%z : undef;
    }

    my @z;
    for (@v) {
        my $i = $_->at($l) or next;
        push @z, $i->text or next;
    }
 
    return @z > 0 ? \@z : undef;
}

sub _get_hash {
    my $s = shift;
    my $d = shift;
    my $f = shift;

    my ($a, @l) = split ' >% ', $f;
    return undef unless @l == 2;

    my $b = "$a > $l[0]";
    my $t = $d->at($b) or return undef;
    my $k = $t->text or return undef;

    my %h = ($k => undef);

    $b = "$a > $l[1]";
    $t = $d->at($b) or return \%h;
    $h{$k} = $t->text;
    return \%h;
}

sub get_org {
     my $s = shift;
     my $p = shift or return;

     my $v = $p->{_poc_org} or return;
     my $o = $org_map{$v} or return;
     $p->{_organization} = "/organization/$o";
     return;
}

sub get_id {
     my $s = shift;
     my $p = shift or return;

     my $v = $p->{_name} or return;
     $p->{name} = $v;
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

