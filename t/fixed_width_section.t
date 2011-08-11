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
    name => 'non-fixed-width-section (missing space after colon)',
    filter_elements => 'Org::Element::FixedWidthSection',
    doc  => <<'_',
:foo
_
    num => 0,
);

test_parse(
    name => 'basic tests',
    filter_elements => 'Org::Element::FixedWidthSection',
    doc  => <<'_',
 :  this is *an* example

   : this is another example

: yet another
:
: with empty line
_
    num  => 3,
    test_after_parse => sub {
        my %args = @_;
        my $elems = $args{elements};
        is($elems->[0]->text, " this is *an* example\n", "#0: text()");
        is($elems->[1]->text, "this is another example\n", "#1: text()");
        is($elems->[2]->text, "yet another\n\nwith empty line\n", "#2: text()");
    },
);

done_testing();
