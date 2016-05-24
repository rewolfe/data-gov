#!/usr/bin/env perl

use v5.20.1;
use Mojo::UserAgent;
use Data::Dumper;

sub see {
  my ($n, $b) = @_;
  my $s;
  $s .= "  " for 1..$n;
  say "$s [$n] ".$b->tag." (".$b->type.")";
  my $a = $b->attr;
#   say " a :\n".Dumper($a);
  my $i = 0;
  for (keys $a) {
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
    see($n, $c);
    children($c, $n);
    $c = $c->next;
  }
}

my $url = 'http://catalog.data.gov/csw-all';

my $ua = Mojo::UserAgent->new;
$ua->max_redirects(3);

my ($r, $h, $n, $f, $o);
$r = 'GetCapabilities';
my $a1 = 'xmlns:csw="http://www.opengis.net/cat/csw/2.0.2"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation=
            "http://www.opengis.net/cat/csw/2.0.2
             http://schemas.opengis.net/csw/2.0.2/CSW-discovery.xsd"
          service="CSW" ';
$a = $a1.
     'xmlns:ows="http://www.opengis.net/ows"';
$o = '<ows:AcceptVersions>
        <ows:Version>2.0.2</ows:Version>
      </ows:AcceptVersions>
      <ows:AcceptFormats>
        <ows:OutputFormat>application/xml</ows:OutputFormat>
      </ows:AcceptFormats>';

$r = 'DescribeRecord';
$a = $a1.
     'version="2.0.2"
      outputFormat="application/xml"
      schemaLanguage="http://www.w3.org/XML/Schema"';
$o = '<csw:TypeName>csw:Record</csw:TypeName>';

$r = 'GetDomain';
$a = $a1.
     'version="2.0.2"';
$n = 'dc:type';
$n = 'GetRecords.outputSchema';
$o = "<csw:PropertyName>$n</csw:PropertyName>";

$r = 'GetRecords';
my $os;
# $os = 'http://www.opengis.net/cat/csw/2.0.2';
$os = 'http://www.isotc211.org/2005/gmd';
$a = $a1.
     'xmlns:ogc="http://www.opengis.net/ogc" 
      version="2.0.2" 
      resultType="results" 
      startPosition="1" 
      maxRecords="15" 
      outputFormat="application/xml"
      outputSchema="'.$os.'"';
my $pn;
$pn = 'dc:title';
# $pn = 'apiso:TopicCategory';
my $f1;
$f1 = '<ogc:PropertyIsLike matchCase="false" wildCard="%"
                           singleChar="_" escapeChar="\">
         <ogc:PropertyName>'.$pn.'</ogc:PropertyName>
         <ogc:Literal>%climate%</ogc:Literal>
       </ogc:PropertyIsLike>';

$f = '<csw:Constraint version="1.1.0">
        <ogc:Filter>'.
          $f1.
       '</ogc:Filter>
      </csw:Constraint> ';
$o = '<csw:Query typeNames="csw:Record">
        <csw:ElementSetName>full</csw:ElementSetName> '.
        $f.
     '</csw:Query>';

my $p = "<csw:$r $a>
           $o 
         </csw:$r>";
say " p : $p";

my $u = $ua->post($url => $p) or die 'post failed';
my $t = $u->res->dom;


# say Dumper($t);

see(0, $t);
children($t, 0);
