#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use DateTime;
use Org::Parser;
use Storable qw(freeze);
use Test::Exception;
use Test::More 0.96;
require "testlib.pl";

test_parse(
    name => 'timestamp basic tests',
    filter_elements => sub {
        $_[0]->isa('Org::Element::Timestamp') },
    doc  => <<'_',
* TODO active timestamps
  without dow & time: <2011-03-23 >
  without dow & time & space: <2011-03-23>
  without dow: <2011-03-23 11:59 >
  without dow & space: <2011-03-23 11:59>
  SCHEDULED: <2011-03-16 Wed>
  TEST: <2011-03-16 Wed 01:23>

* inactive timestamps
  - [2011-03-23 ]
  - [2011-03-23]
  - [2011-03-23 Wed]
  - [2011-03-23 Wed 01:23]
  - [2011-03-23 01:23]

* additional tests
  - <2012-01-11 Wed > # space after dow allowed
  - [2012-01-11   ] [2012-01-11   Wed   ] # multiple spaces allowed
_
    num => 14,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        is(DateTime->compare(DateTime->new(year=>2011, month=>3, day=>23),
                             $elems->[0]->datetime), 0, "ts[0] datetime")
            or diag("datetime=".$elems->[0]->datetime);

        # active
        is( $elems->[0]->as_string, "<2011-03-23 >");
        is( $elems->[1]->as_string, "<2011-03-23>");
        is( $elems->[2]->as_string, "<2011-03-23 11:59 >");
        is( $elems->[3]->as_string, "<2011-03-23 11:59>");
        is( $elems->[4]->as_string, "<2011-03-16 Wed>");
        is( $elems->[5]->as_string, "<2011-03-16 Wed 01:23>");

        # inactive
        is( $elems->[6]->as_string, "[2011-03-23 ]");
        is( $elems->[7]->as_string, "[2011-03-23]");
        is( $elems->[8]->as_string, "[2011-03-23 Wed]");
        is( $elems->[9]->as_string, "[2011-03-23 Wed 01:23]");
        is( $elems->[10]->as_string, "[2011-03-23 01:23]");

        ok( $elems->[0]->is_active);
        ok(!$elems->[6]->is_active);

        # additional
        is($elems->[11]->as_string,"<2012-01-11 Wed >");
        is($elems->[12]->as_string,"[2012-01-11   ]");
        is($elems->[13]->as_string,"[2012-01-11   Wed   ]");
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
<2011-05-25 Wed +17.1m -13.2d>

# habit-style repeater
[2011-03-23 Wed 10:12 +1d/2d]
[2011-03-23 Wed 10:12 +1w/10d]
[2011-03-23 Wed 10:12-11:23 +2w/3w]
_
    num => 10,
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
        is($elems->[6]->_repeater, "+17.1m", "[6] _repeater");
        is($elems->[6]->_warning_period, "-13.2d", "[6] _warning_period");

        is($elems->[7]->_repeater, "+1d/2d", "[7] _repeater");
        is($elems->[8]->_repeater, "+1w/10d", "[8] _repeater");
        is($elems->[9]->_repeater, "+2w/3w", "[9] _repeater");

        # make sure warning period is stringified as-is
        is($elems->[6]->as_string, "<2011-05-25 Wed +17.1m -13.2d>",
           "[6] as_string");
        # make sure habit-style repeater is stringified as-is
        is($elems->[7]->as_string, "[2011-03-23 Wed 10:12 +1d/2d]",
           "[7] as_string");

        ok($elems->[0]->recurrence->isa('DateTime::Set::ICal'),
           "[0] recurrence");
    },
);

test_parse(
    name => 'time_zone',
    filter_elements => sub {
        $_[0]->isa('Org::Element::Timestamp') },
    parser_opts => {time_zone => 'Asia/Jakarta'},
    doc  => <<'_',
[2011-09-23 Wed]
_
    num => 1,
    test_after_parse => sub {
        my %args  = @_;
        my $doc   = $args{result};
        my $elems = $args{elements};
        my $dt    = $elems->[0]->datetime;
        my $tz    = $dt->time_zone;
        like($tz->short_name_for_datetime($dt),
             qr/^WI[BT]$/, # newer tzdb uses WIB, older uses WIT
             "time zone's short name");
    },
);

test_parse(
    name => 'clear_parse_results',
    filter_elements => sub { $_[0]->isa('Org::Element::Timestamp') },
    doc  => <<'_',
[2012-07-23 Mon +1y]
_
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        dies_ok { freeze $doc }
            'timestamp object with recurrence contains coderef, unserializable';
        my $elem = $args{elements}[0];
        $elem->clear_parse_result;
        lives_ok { freeze $doc }
            'after clear_parse_result, coderef is removed, object serializable';
        isa_ok($elem->datetime, 'DateTime',
               'if attribute accessed, timestamp automatically parsed again');
    },
);

done_testing();
