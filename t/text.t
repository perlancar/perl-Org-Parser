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
0) this is normal.
*1) this /is/ bold.*
/3) this *is* italic./
_5) this is underline._
+7) this is strike-through.+
=9) this is code.=
~11) this is verbatim.~

unparsed: *ends with spaces *, / start with space/, =no ending. no starting.~
_
    num => 14,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        #diag(explain [map {$_->as_string} @$elems]);
        ok(!$elems->[ 0]->style,      "elem 0 normal");
        is( $elems->[ 1]->style, "B", "elem 2 bold");
        is( $elems->[ 3]->style, "I", "elem 2 italic");
        is( $elems->[ 5]->style, "U", "elem 2 underline");
        is( $elems->[ 7]->style, "S", "elem 2 strike-through");
        is( $elems->[ 9]->style, "C", "elem 2 code");
        is( $elems->[11]->style, "V", "elem 2 verbatim");
        ok(!$elems->[12]->style,      "elem 13 normal");
        # elem [13] = headline's title (text)
        is( $elems->[ 0]->as_string, "0) this is normal.\n",
            "normal as_string");
        is( $elems->[ 1]->as_string, "*1) this /is/ bold.*",
            "bold as_string");
        is( $elems->[ 3]->as_string, "/3) this *is* italic./",
            "italic as string");
        is( $elems->[ 5]->as_string, "_5) this is underline._",
            "underline as_string");
        is( $elems->[ 7]->as_string, "+7) this is strike-through.+",
            "strike-through as_string");
        is( $elems->[ 9]->as_string, "=9) this is code.=",
            "code as_string");
        is( $elems->[11]->as_string, "~11) this is verbatim.~",
            "verbatim as_string");
    },
);

# emacs allows ( and { as well as whitespace to start markup
test_parse(
    name => 'markup start characters',
    filter_elements => 'Org::Element::Text',
    doc  => <<'_',
_underlined_
 _underlined_
(_underlined_)
{_underlined_}
<_not underlined_>
[_not underlined_]
_
    num => 6, # should be 8, curly does not work yet
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        note(explain [map {$_->as_string} @$elems]);
        is( $elems->[ 0]->style, "U");
        is( $elems->[ 2]->style, "U");
        is( $elems->[ 4]->style, "U");
        #is( $elems->[ 6]->style, "U");
    },
);

# emacs only allows a single newline in markup
test_parse(
    name => 'max newlines',
    filter_elements => 'Org::Element::Text',
    doc  => <<'_',
=this is
still code=

=this is
no longer
code=
_
    num => 2,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        #diag(explain [map {$_->as_string} @$elems]);
        is( $elems->[0]->style, "C", "elem 0 code");
        ok(!$elems->[1]->style,      "elem 1 normal");

        is( $elems->[0]->as_string, "=this is\nstill code=",
            "elem 0 as_string");
        is( $elems->[1]->as_string, "\n\n=this is\nno longer\ncode=\n",
            "elem 1 as_string");
    },
);

# markup can contain links, even *[[link][description with * in it]]*. also
# timestamp, etc.
test_parse(
    name => 'link inside markup',
    filter_elements => 'Org::Element::Text',
    doc  => <<'_',
*bolded [[link]]*
_
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        is($elems->[0]->style, "B", "elem 0 bold");
        is($elems->[0]->children->[0]->as_string, "bolded ",
           "bolded text");
        is(ref($elems->[0]->children->[1]), "Org::Element::Link",
           "link inside bolded");
    },
);

done_testing();

