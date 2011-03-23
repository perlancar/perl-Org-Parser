#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use DateTime;
use Org::Parser;
use Test::More 0.96;
require "testlib.pl";

test_parse(
    name => 'timerange basic tests',
    filter_elements => sub {
        $_[0]->isa('Org::Element::TimeRange') },
    doc  => <<'_',
* TODO active timeranges
<2011-03-23 Wed>--<2011-03-24 Thu>
<2011-03-23 >--<2011-03-24 >
<2011-03-23 Wed 01:23>--<2011-03-23 Wed 03:59>

* inactive timeranges
[2011-03-23 Wed]--[2011-03-24 Thu]
[2011-03-23 ]--[2011-03-24 ]
[2011-03-23 Wed 01:23]--[2011-03-23 Wed 03:59]

* non-timeranges
[2011-03-22 ]--<2011-03-23 > # mixed active & inactive timestamp
<2011-03-22 >--[2011-03-23 ] # mixed active & inactive timestamp

_
    num => 6,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        ok( $elems->[0]->ts1->is_active, "tr[0] is_active");
        ok(!$elems->[3]->ts1->is_active, "tr[3] !is_active");
    },
);

test_parse(
    name => 'event duration not allowed in timerange',
    filter_elements => sub {
        $_[0]->isa('Org::Element::TimeRange') },
    doc  => <<'_',
<2011-03-23 Wed 11:28-12:00>--<2011-03-24 Thu>
_
    dies => 1,
);

test_parse(
    name => 'repeater not allowed in timerange',
    filter_elements => sub {
        $_[0]->isa('Org::Element::TimeRange') },
    doc  => <<'_',
<2011-03-23 Wed +1w>--<2011-03-24 Thu>
_
    dies => 1,
);

done_testing();
