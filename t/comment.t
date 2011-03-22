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
    name => 'comment basic tests',
    filter_elements => 'Org::Element::Comment',
    doc  => <<'_',
# single line comment

# *multi*
#line
# comment
#

 # not comment (not started on line 1)
_
    num => 2,
    test_after_parse => sub {
        my %args  = @_;
        my $doc   = $args{result};
        my $elems = $args{elements};
        #diag(explain [map {$_->as_string} @$elems]);
        is( $elems->[0]->as_string, "# single line comment\n",
           "comment[0] content");
        is( $elems->[1]->as_string, "# *multi*\n#line\n# comment\n#\n",
           "comment[1] content");
        ok(!$elems->[1]->children,
           "markup not parsed in comment");
    },
);

done_testing();

