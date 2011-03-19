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
[[link1]]
[[link2][description2]]

# non-links
[[]]      # empty link
[[x][]]   # empty description
[[x] [x]] # there should not be a space between link & description
_
    num => 2,
    test_after_parse => sub {
        my %args  = @_;
        my $doc   = $args{result};
        my $elems = $args{elements};
        is( $elems->[0]->link       , "link1",        "0: link");
        ok(!$elems->[0]->description,                 "0: description");
        is( $elems->[1]->link       , "link2",        "1: link");
        is( $elems->[1]->description, "description2", "1: description");
    },
);

done_testing();

