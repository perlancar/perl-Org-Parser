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
    name => 'text basic tests',
    filter_elements => 'Org::Element::Text',
    doc  => <<'_',
* just some heading, not bold*
0. this is normal.
*2. this /is/ bold.*
/4. this *is* italic./
_6. this is underline._
+8. this is strike-through.+
=10. this is code.=
~12. this is verbatim.~

unparsed: *ends with spaces *, / start with space/, =no ending. no starting.~
_
    num => 14,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        ok(!$elems->[ 1]->style,      "elem 0 normal");
        is( $elems->[ 2]->style, "B", "elem 2 bold");
        is( $elems->[ 4]->style, "I", "elem 2 italic");
        is( $elems->[ 6]->style, "U", "elem 2 underline");
        is( $elems->[ 8]->style, "S", "elem 2 strike-through");
        is( $elems->[10]->style, "C", "elem 2 code");
        is( $elems->[12]->style, "V", "elem 2 verbatim");
        ok(!$elems->[13]->style,      "elem 13 normal");

        is( $elems->[ 1]->as_string, "0. this is normal.\n",
            "normal as_string");
        is( $elems->[ 2]->as_string, "*2. this /is/ bold.*",
            "bold as_string");
        is( $elems->[ 4]->as_string, "/4. this *is* italic./",
            "italic as string");
        is( $elems->[ 6]->as_string, "_6. this is underline._",
            "underline as_string");
        is( $elems->[ 8]->as_string, "+8. this is strike-through.+",
            "strike-through as_string");
        is( $elems->[10]->as_string, "=10. this is code.=",
            "code as_string");
        is( $elems->[12]->as_string, "~12. this is verbatim.~",
            "verbatim as_string");
    },
);

# TODO: emacs only supports at most 2 line of markup, e.g.
#
#  =this is
#  still code=
#
# but:
#
#  =this is
#  no longer
#  code=

done_testing();

