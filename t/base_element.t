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
    name => 'seniority(), prev_sibling(), next_sibling()',
    filter_elements => 'Org::Element::Headline',
    doc  => <<'_',
* h1
** h2a
** h2b
** h2c
_
    num => 4,
    test_after_parse => sub {
        my (%args) = @_;
        my $h = $args{elements};
        is($h->[0]->seniority, 0, "h1's seniority=0");
        is($h->[1]->seniority, 0, "h2a's seniority=0");
        is($h->[2]->seniority, 1, "h2b's seniority=1");
        is($h->[3]->seniority, 2, "h2c's seniority=2");

        ok(!defined($h->[0]->prev_sibling), "h1 doesnt have prev_sibling");
        ok(!defined($h->[1]->prev_sibling), "h2a doesnt have prev_sibling");
        is($h->[2]->prev_sibling->title->as_string, "h2a",
           "h2b's prev_sibling=h2a");
        is($h->[3]->prev_sibling->title->as_string, "h2b",
           "h2c's pre_sibling=h2b");

        ok(!defined($h->[0]->prev_sibling), "h1 doesnt have next_sibling");
        is($h->[1]->next_sibling->title->as_string, "h2b",
           "h2a's next_sibling=h2b");
        is($h->[2]->next_sibling->title->as_string, "h2c",
           "h2b's next_sibling=h2c");
        ok(!defined($h->[3]->next_sibling), "h2c doesnt have next_sibling");
    },
);

test_parse(
    name => 'walk()',
    doc  => <<'_',
#comment
* h <2011-03-22 >
text
_
    test_after_parse => sub {
        my (%args) = @_;
        my $doc = $args{result};

        my $n=0;
        $doc->walk(sub{$n++});
        # +1 is for document itself
        # timestamp not walked (part of headline)
        is($n, 3+1, "num of walked elements");
    },
);

done_testing();
