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
    name => 'active timestamp',
    filter_elements => sub {
        $_[0]->isa('Org::Element::Timestamp') && $_[0]->is_active },
    doc  => <<'_',
* TODO foo
  SCHEDULED: <2011-03-16 Tue>
  TEST: <2011-03-16 >
  TEST: <2011-03-16 Tue 01:23>
_
    num => 3,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        is(DateTime->compare(DateTime->new(year=>2011, month=>3, day=>16),
                             $elems->[0]->datetime),
           0, "datetime");
    },
);

done_testing();
