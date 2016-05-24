package Org;

use v5.18.2;
use Gcis::Client;
use Data::Dumper;

sub new {
    my $class = shift;
    my $g = shift;
    my $s;
    my $s->{g} = $g;
    bless $s, $class;
    return $s;
}

sub uri {
    my ($s, $i) = @_;

    return undef unless $i;

    my $g = $s->{g};

    my $v;
    while (1) {
        last if ($v = $s->_acro($i));
        last if ($v = $g->get("/lexicon/govman/agencyName/$i"));
        last if ($v = $s->_special($i));
        last if ($v = $s->_org($i));
        return undef;
    }
    my $u = $v->{uri};

    return $u ? $u : undef;
}

sub strip {
    my ($s, $o) = @_;

    return undef unless $o;

    $o = lc $o;
    $o =~ s/[,\-\/>\(\):_]/ /g;
    $o =~ s/ & / /g;
    $o =~ s/ &amp; / /g;
    $o =~ s/u\. *s\. /us /g;
    $o =~ s/\./ /g;
    $o =~ s/united states /us /g;
    $o =~ s/ (and|of|for|the) / /g;
    $o =~ s/^the +//;
    $o =~ s/^ +//;
    $o =~ s/ +$//;
    $o =~ s/ +/-/g;

    return $o;
}

sub bureau {
    my ($s, $u) = @_;

    my $g = $s->{g};

    my $v = $g->get($u) or do {
        say " warning - uri not found : $u";
        return undef;
    };
    $a = $v->{aliases} or return undef;
    my $b;
    for (@{ $a }) {
        next unless $_->{lexicon} eq "omb";
        next unless $_->{context} eq "agency:bureau";
        $b = $_->{term};
        last;
    }

    return $b;
}

sub _acro {
    my ($s, $o) = @_;

    return undef if length $o > 6;
    $o = uc $o;

    my $g = $s->{g};
    my $v = $g->get("/lexicon/govman/Agency/$o");

    return $v;
}

sub _special {
    my ($s, $o) = @_;

    $o =~ s/ &amp; / & /g;
    $o =~ s/ Montioring / Monitoring /g;
    $o =~ s/^US Gelogical /U.S. Geological /;

    my $g = $s->{g};
    my $v = $g->get("/lexicon/datagov/Organization/$o");

    return $v;
}

sub _org {
    my ($s, $o) = @_;

    $o = $s->strip($o) or return undef;

    my $g = $s->{g};
    my $v = $g->get("/organization/$o");

    return $v if $v;

    my @l = split '-', $o;
    my $n = @l;
    return undef unless $n > 1;

    my $a = pop @l;
    my $v = $s->_acro($a);

    return $v;
}

1;
