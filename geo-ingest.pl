#!/usr/bin/env perl

use v5.18.1;
use Mojo::UserAgent;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use DateTime::Format::ISO8601;
use YAML::XS qw/Dump/;
use Iso;

my $max_items = -1;
my $example = 0;
my $dump_meta1 = 0;
my $dump_meta2 = 0;
my $base_url = 'http://catalog.data.gov/';
my $ckan_url = $base_url.'api/3/action/';
my $wcs_url = $base_url.'csw-all/';

my %d;
my $ex = 'C1178-NSIDCV0';
# my $ex = 'C1178-NSIDCV0__1';

if (!$example) {
    %d = get_group($ckan_url, 'climate5434');
} else {
    $d{$ex} = 
        { idAgency => $ex, 
          title => 'Arctic Sea Ice Freeboard and Thickness',
        };
}

my @n;
for (keys %d) {
    my $b = %d{$_};
    push @n, get_meta($wcs_url, \%{ $b });
}
say Dump(\@n);

exit;

sub get_group {
    my ($u, $k) = @_;

    my $ua = Mojo::UserAgent->new;
    $ua->max_redirects(3);

    my $p = 'package_search?q=groups:'.$k;

    my %d;

    my $n = 0;
    while () {
      my $s = '&start='.$n;
      my $t = $ua->get($u.$p.$s)->res->json or die 'ckan get failed';
      my $r = $t->{result}->{results};
      scalar @{ $r } or last;
      for (@{ $r }) {
          # say " r :\n".Dumper($_);
          my $v = \%{ $d{$_->{id}} };
          $v->{idDataGov} = $_->{id};
          $v->{idAgency} = get_id_agency($_);
          for my $i (qw(title name)) {
              next unless $_->{$i};
              $v->{$i} = $_->{$i};
          }
          if ($_->{organization}->{title}) {
              $v->{organization} = $_->{organization}->{title};
          }
          my $e = $_->{extras};
          get_extent($e, $v);
          for (@{ $e }) {
              my $k = $_->{key};
              if (grep $k eq $_, qw(programCode bureauCode)) {
                  $v->{$k} = $_->{value}[0];
              } elsif (grep $k eq $_, qw(describedBy landingPage)) {
                  $v->{$k} = $_->{value};
              }
          }
      }
      $n = keys %d;
      if ($max_items > 0) {
        last if $n >= $max_items;
      }
    }

    return %d;
}

sub get_extent {
    my ($e, $v) = @_;
    for (@{ $e }) {
        $v->{spatial} = get_spatial($_->{value}) if $_->{key} eq 'spatial';
        $v->{temporal} = get_temporal($_->{value}) if $_->{key} eq 'temporal';
    }
    return;
}

sub get_spatial {
    my $s = shift;

    my %m;
    my $b1 = qq({"type": *"Polygon", *"coordinates": *);
    my $e1 = quotemeta qq(});
    my $b2 = quotemeta 
        qq(<gml:outerBoundaryIs><gml:LinearRing><gml:posList>);
    my $e2 = quotemeta 
        qq(</gml:posList></gml:LinearRing></gml:outerBoundaryIs>);
    my $poly = 0;
    my $p;
    if ($s =~ /^$b1/  &&  $s =~ /$e1$/ ) { 
        ($p) = ($s =~ /^$b1(.*?)$e1$/);
        $p =~ s/^\[\[\[//;
        $p =~ s/\]\]\]$//;
        $p =~ s/\], *\[/ /g;
        $p =~ s/, */ /g;
        $poly = 1;
    } elsif ($s =~ /$b2/  &&  $s =~ /$e2/ ) {
        ($p) = ($s =~ /$b2(.*?)$e2/);
        $poly = 2;
    }
    if ($poly) {
        my @c = split / /, $p;
        my $n = grep looks_like_number($_), @c;
        if ($n != 10  ||  scalar @c != 10) {
            say " error : not a four sided polygon";
            say "         value : $s";
            return undef;
        }
        my $i = 0;
        my $j = 0;
        my @lon;
        my @lat;
        while ($i < 10) {
            if ($poly == 1) {
               $lon[$j] = $c[$i++];
               $lat[$j] = $c[$i++];
            } else {
               $lat[$j] = $c[$i++];
               $lon[$j] = $c[$i++];
            }
            # say " lon : $lon[$j]  lat : $lat[$j]";
            $j++;
        }
        if ($lon[0] != $lon[4]) {
            say " error : first and last longitude don't match in polygon";
            say "         value : $s";
            return undef;
        }
        if ($lat[0] != $lat[4]) {
            say " error : first and last latitude don't match in polygon";
            say "         value : $s";
            return undef;
        }

        ($m{lon_min}, $m{lon_max}) = min_max(@lon);
        ($m{lat_min}, $m{lat_max}) = min_max(@lat);
        if ($lon[0] > $lon[1]) {
           my $t = $m{lon_min};
           $m{lon_min} = $m{lon_max};
           $m{lon_min} = $t;
        }
        return valid_lat_lon(%m) ? \%m : undef;
    }

    my $b3 = qq({"type": *"Point", *"coordinates": *);
    my $e3 = quotemeta qq(});
    if ($s =~ /^$b3/  &&  $s =~ /$e3$/ ) {
        ($p) = ($s =~ /^$b3(.*?)$e3$/);
        $p =~ s/^\[//;
        $p =~ s/\]$//;
        my (@c) = split /, */, $p;
        my $n = grep looks_like_number($_), @c;
        if ($n != 2  ||  scalar @c != 2) {
            say " error : not a point";
            say "         value : $s";
            return undef;
        }
        $m{lon_min} = $c[0];
        $m{lon_max} = $c[0];
        $m{lat_min} = $c[1];
        $m{lat_max} = $c[1];
        return valid_lat_lon(%m) ? \%m : undef;
    }

    my @p = split /, */, $s;
    if (@p != 4) {
        @p = split / +/, $s;
    }
    my $n = grep looks_like_number($_), @p;
    if ($n == 4  &&  scalar @p == 4) {
        # say " p :\n".Dumper(@p);
        ($m{lon_min}, $m{lat_min}, $m{lon_max}, $m{lat_max}) = @p;
        return valid_lat_lon(%m) ? \%m : undef;
    }

    say " error - spatial not a polygon or bounding box";
    say "         value : $s";
    return undef;
}

sub valid_lat_lon {
    my %m = @_;

    if ($m{lat_min} > $m{lat_max}  ||
        $m{lat_min} < -90.0  ||  $m{lat_min} > 90.0  ||
        $m{lat_max} < -90.0  ||  $m{lat_max} > 90.0) {
        say " error : minimum and/or maximum latitude invalid";
        say "         lat_min : $m{lat_min}  lat_max : $m{lat_max}";
        return 0;
    }
    if ($m{lon_min} < -180.0  ||  $m{lon_min} > 180.0  ||
        $m{lon_max} < -180.0  ||  $m{lon_max} > 180.0) {
        say " error : minimum and/or maximum longitude invalid";
        say "         lon_min : $m{lon_min}  lon_max : $m{lon_max}";
        return 0;
    }

    return 1;
}

sub min_max {
    my @s = @_;
    my $first = 1;
    my ($a, $b);
    for (@s) {
        if ($first) {
            $a = $_;
            $b = $_;
            $first = 0;
            next;
        }
        $a = $_ if $_ < $a;
        $b = $_ if $_ > $b;
    }
    return ($a, $b);
}

sub get_temporal {
    my $s = shift;

    my (@c) = split '/', $s;
    my %t;

    my $n = @c;
    if ($c[0] eq "R") {
        if ($n != 3  ||  $c[2] !~ /^P\d*[YMD]/) {
            say " error : invalid repeating temporal extent";
            say "         value : $s";
            return undef;
        }
        if (!eval { DateTime::Format::ISO8601->parse_datetime($c[1]) }) {
            say " error : invalid date time";
            say "         value : $s";
            return undef;
        }
        $t{start_time} = $c[1];
        return \%t;
    }
    if ($n != 2) {
        say " error : invalid temporal extent";
        say "         value : $s";
        return undef;
    }
    for (@c) {
        next if eval { DateTime::Format::ISO8601->parse_datetime($_) };
        say " error : invalid date time";
        say "         value : $s";
        return undef;
    }
    $t{start_time} = $c[0];
    $t{end_time} = $c[1];
    return \%t;
}
 
sub get_id_agency {
    my $d = shift;
    for my $v (@{ $d->{extras} }) {
         for (qw(guid identifier)) {
            next unless $v->{key} eq $_;
            return $v->{value} if $v->{value};
        }
    }
    return $d->{id};
}

sub get_meta {
    my ($u, $d) = @_;

    my %v;
    $v{_ckan}->{$_} = $d->{$_} for keys %{ $d };

    my $ua = Mojo::UserAgent->new;
    $ua->max_redirects(3);

    my $p2_prefix = 
        '<csw:GetRecords
           xmlns:csw="http://www.opengis.net/cat/csw/2.0.2"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xsi:schemaLocation=
             "http://www.opengis.net/cat/csw/2.0.2
              http://schemas.opengis.net/csw/2.0.2/CSW-discovery.xsd"
           service="CSW"
           xmlns:ogc="http://www.opengis.net/ogc"
           version="2.0.2"
           resultType="results"
           startPosition="1"
           maxRecords="15"
           outputFormat="application/xml"
           outputSchema="http://www.isotc211.org/2005/gmd">
           <csw:Query typeNames="csw:Record">
             <csw:ElementSetName>full</csw:ElementSetName>
             <csw:Constraint version="1.1.0">
               <ogc:Filter>';
    my $p2_suffix = 
              '</ogc:Filter>
             </csw:Constraint>
           </csw:Query>
         </csw:GetRecords>';

    my $r;
    my $n = 0;

    my %prop = (idAgency => 'identifier', title => 'title');
    for (keys %prop) {
        next unless $d->{$_};
        my $f = 
            '<ogc:PropertyIsEqualTo>
               <ogc:PropertyName>dc:'.$prop{$_}.'</ogc:PropertyName>
               <ogc:Literal>'.$d->{$_}.'</ogc:Literal>
             </ogc:PropertyIsEqualTo>';
        my $p = $p2_prefix.$f.$p2_suffix;
        # say " p : $p";

        my $u = $ua->post($u => $p) or die 'wcs post failed';
        my $m = $u->res->dom;
        if ($example && $dump_meta1) {
            see_meta(0, $m);
            children($m, 0);
        }

        $r = $m->at('csw\:GetRecordsResponse > csw\:SearchResults');
        if (!$r) {
            say " error - no response";
            next;
        }
        $n = $r->attr->{numberOfRecordsMatched};
        last if $n == 1;
    }
    if ($n != 1) {
        $v{_ckan}->{numberOfMatches} = $n;
        return \%v;
    }

    my $r1 = $r->at('gmd\:MD_Metadata');
    $r1 or $r1 = $r->at('gmi\:MI_Metadata');
    if ($example  &&  $dump_meta2) {
        see_meta(0, $r1);
        children($r1, 0);
    }

    my $s = Iso->set_dom($r1, $d->{idAgency});
    my $v1 = $s->get_meta;
    @v{keys %$v1} = values %$v1;

    for my $e (qw(spatial temporal)) {
        next unless $v{_ckan}->{$e};
        for (keys %{ $v{_ckan}->{$e} }) {
            next if $v{$_};
            $v{$_} = $v{_ckan}->{$e}->{$_};
        }
    }

    fix_poc(\%v);

    return \%v;
}

sub see_meta {
    my ($n, $b) = @_;
    my $s;
    $s .= "  " for 1..$n;
    say "$s [$n] ".$b->tag." (".$b->type.")";
    my $a = $b->attr;
    # say " a :\n".Dumper($a);
    my $i = 0;
    for (keys %{ $a }) {
        say "$s     ".($i eq 0 ? "attr" : "    ")." [$i] : $_ => ".$a->{$_};
        $i++;
    }
    say "$s     text : ".$b->text if $b->text;
}

sub children {
    my ($p, $n) = @_;

    $n++;
    my $c = $p->children->first;
    while ($c) {
        see_meta($n, $c);
        children($c, $n);
        $c = $c->next;
    }
    return;
}

sub fix_poc {
    my $d = shift;

    # my $at = '@type';
    # my $t = qq({u'subOrganizationOf': {u'subOrganizationOf': {u'name': u'U.S. Government'}, u'name': u'National Aeronautics and Space Administration'}, u'name': u'NSIDC'});
    # my $t = qq({u'$at': u'org:Organization', u'name': u'Centers for Disease Control and Prevention'});
    # my $d->{_poc_org} = $t;

    my $v = $d->{_poc_org} or return;


    my $t = '@type';
    my $n = qq(u'name': *u');
    my $o = qq(u'$t': *u'org:Organization', *$n);

    if ($v =~ /^{$o.+'}$/ ) {
        ($d->{_poc_org}) = ($v =~ /^{$o(.+)'}$/);
        return;
    }

    my $so = qq(u'subOrganizationOf': *{);    

    if ($v =~ /^{$so$o.+}, *$o.+'}$/) {
        my ($org, $sub_org) = ($v =~ /^{$so$o(.+)}, *$o(.+)'}$/);
        $d->{_poc_org} = "$sub_org, $org";
        return;
    }

    return unless $v =~ /^{$so$so$n.+'}, *$n.+'}, *$n.+'}$/;
    my ($org, $sub_org1, $sub_org2) = ($v =~ /^{$so$so$n(.+)'}, *$n(.+)'}, *$n(.+)'}$/);
    $d->{_poc_org} = "$sub_org2, $sub_org1, $org";

    return;
}
