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
    name => 'radio target basic tests',
    filter_elements => 'Org::Element::Link',
    doc  => <<'_',
target1, nottarget 1
target 2, nottarget 2

not target
2

not
target

<<<target1>>> <<<target 2>>>
<<<not
target>>>

target1

[[normal link]]
_
    num => 3 +1,
    test_after_parse => sub {
        my %args  = @_;
        my $doc   = $args{result};
        my $elems = $args{elements};
        is($elems->[0]->link, "target1" , "link[0]");
        is($elems->[1]->link, "target 2", "link[1]");
        is($elems->[2]->link, "target1" , "link[2]");

        ok( $elems->[0]->from_radio_target, "from_radio_target[0]");
        ok( $elems->[1]->from_radio_target, "from_radio_target[1]");
        ok( $elems->[2]->from_radio_target, "from_radio_target[2]");
        ok(!$elems->[3]->from_radio_target, "from_radio_target[3]");
    },
);

done_testing();

