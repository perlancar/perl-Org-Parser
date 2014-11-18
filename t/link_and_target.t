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
    name => 'link basic tests',
    filter_elements => 'Org::Element::Link',
    doc  => <<'_',
# links
[[link1]]
[[link2][description2]]
[[link3][description
*can* contain markups]]

# non-links
[[]]      # empty link
[[x][]]   # empty description
[[x] [x]] # there should not be a space between link & description
[[x
y] [x]]   # link cannot contain newline
_
    num => 3,
    test_after_parse => sub {
        my %args  = @_;
        my $doc   = $args{result};
        my $elems = $args{elements};
        is( $elems->[0]->link       , "link1",          "0: link");
        ok(!$elems->[0]->description,                   "0: description");
        is( $elems->[0]->as_text    , "link1",          "0: as_text");
        is( $elems->[1]->link       , "link2",          "1: link");
        is( $elems->[1]->description->as_string,
            "description2",                             "1: description");
        is( $elems->[1]->as_text    , "description2",   "1: as_text");
        is( $elems->[2]->link       , "link3",          "2: link");
        is( $elems->[2]->description->as_string,
            "description\n*can* contain markups",       "2: description");
    },
);

test_parse(
    name => 'RT#82334',
    filter_elements => 'Org::Element::Link',
    doc  => <<'_',
[[link][some *description*]]
_
    num => 1,
    test_after_parse => sub {
        my %args  = @_;
        my $doc   = $args{result};
        my $elems = $args{elements};
        my $link  = $elems->[0];
        is($link->as_string, "[[link][some *description*]]");
    },
);

# TODO: target cannot contain newline
# TODO: radio target cannot contain newline

done_testing();

