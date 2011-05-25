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
    name => 'timestamp basic tests',
    filter_elements => sub {
        $_[0]->isa('Org::Element::Timestamp') },
    doc  => <<'_',
* TODO active timestamps
  SCHEDULED: <2011-03-16 Wed>
  TEST: <2011-03-16 >
  TEST: <2011-03-16 Wed 01:23>
  nontimestamps: <2011-03-23>

* inactive timestamps
  - [2011-03-23 Wed]
  - [2011-03-23 ]
  - [2011-03-23 Wed 01:23]
  - nontimestamps: [2011-03-23]
_
    num => 6,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        is(DateTime->compare(DateTime->new(year=>2011, month=>3, day=>16),
                             $elems->[0]->datetime), 0, "ts[0] datetime")
            or diag("datetime=".$elems->[0]->datetime);

        is( $elems->[0]->as_string, "<2011-03-16 Wed>", "ts[0] as_string");
        is( $elems->[1]->as_string, "<2011-03-16 Wed>", "ts[1] as_string");
        is( $elems->[2]->as_string, "<2011-03-16 Wed 01:23>",
            "ts[2] as_string");
        is( $elems->[3]->as_string, "[2011-03-23 Wed]",
            "ts[2] as_string");

        ok( $elems->[0]->is_active, "ts[0] is_active");
        ok(!$elems->[3]->is_active, "ts[3] !is_active");
    },
);

test_parse(
    name => 'event duration',
    filter_elements => sub {
        $_[0]->isa('Org::Element::Timestamp') },
    doc  => <<'_',
[2011-03-23 Wed 10:12-11:23]
_
    num => 1,
    test_after_parse => sub {
        my %args  = @_;
        my $doc   = $args{result};
        my $elems = $args{elements};
        my $ts    = $elems->[0];
        is(DateTime->compare(DateTime->new(year=>2011, month=>3, day=>23,
                                           hour=>10, minute=>12),
                             $ts->datetime), 0, "datetime")
            or diag("datetime=".$ts->datetime);
        is($elems->[0]->event_duration, 1*3600+11*60, "event_duration");
    },
);

test_parse(
    name => 'repeater & warning period',
    filter_elements => sub {
        $_[0]->isa('Org::Element::Timestamp') },
    doc  => <<'_',
[2011-03-23 Wed 10:12 +1d]
[2011-03-23 Wed 10:12-11:23 +2w]
[2011-03-23 Wed +3m]
[2011-03-23 Wed +4y]
<2011-05-25 Wed ++5m>
<2011-05-25 Wed .+6m>
<2011-05-25 Wed +7m -3d>
_
    num => 7,
    test_after_parse => sub {
        my %args  = @_;
        my $doc   = $args{result};
        my $elems = $args{elements};
        is($elems->[0]->_repeater, "+1d", "[0] _repeater");
        is($elems->[1]->_repeater, "+2w", "[1] _repeater");
        is($elems->[2]->_repeater, "+3m", "[2] _repeater");
        is($elems->[3]->_repeater, "+4y", "[3] _repeater");
        is($elems->[4]->_repeater, "++5m", "[4] _repeater");
        is($elems->[5]->_repeater, ".+6m", "[5] _repeater");
        is($elems->[6]->_repeater, "+7m", "[6] _repeater");
        is($elems->[6]->_warning_period, "-3d", "[6] _warning_period");

        ok($elems->[0]->recurrence->isa('DateTime::Set::ICal'),
           "[0] recurrence");
    },
);

done_testing();
