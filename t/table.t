#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Org::Parser;
use Test::More 0.96;
require "testlib.pl";

test_parse(
    name => 'non-table (missing extra character)',
    filter_elements => 'Org::Element::Table',
    doc  => <<'_',
|
_
    num => 0,
);

test_parse(
    name => 'table',
    filter_elements => 'Org::Element::Table',
    doc  => <<'_',
#+CAPTION: test caption
#+LABEL: tbl:test
| a | b   | c |
|---+-----+---|
| 1 |     | 2 |
| 3 | abc | 4 |
| one <2011-03-17 > three
_
    num  => 1,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        my $t = $elems->[0];
        my ($r1, $r2, $r3, $r4, $r5) = @{ $t->children };
        isa_ok($r1, "Org::Element::TableRow");
        isa_ok($r2, "Org::Element::TableVLine");
        isa_ok($r3, "Org::Element::TableRow");
        isa_ok($r4, "Org::Element::TableRow");

        my $c1a = $r1->children->[0];
        isa_ok($c1a, "Org::Element::TableCell");
        isa_ok($c1a->children->[0], "Org::Element::Text");

        is($c1a->as_string, "a", "first cell's as_string");
        is($r1->as_string, "|a|b|c\n", "first row's as_string");

        # test inline elements inside cell
        my $c5a = $r5->children->[0];
        isa_ok($c5a->children->[0], "Org::Element::Text");
        isa_ok($c5a->children->[1], "Org::Element::ScheduleTimestamp");
        isa_ok($c5a->children->[2], "Org::Element::Text");
    },
);

done_testing();

