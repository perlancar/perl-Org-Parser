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
    name => 'non-short-example (missing space after colon)',
    filter_elements => 'Org::Element::ShortExample',
    doc  => <<'_',
:foo
_
    num => 0,
);

test_parse(
    name => 'basic tests',
    filter_elements => 'Org::Element::ShortExample',
    doc  => <<'_',
 :  this is *an* example
   : this is another example
_
    num  => 2,
    test_after_parse => sub {
        my %args = @_;
        my $elems = $args{elements};
        is($elems->[0]->indent, " ", "indent attribute");
        is($elems->[0]->example, " this is *an* example", "example attribute");
        is($elems->[0]->as_string, " :  this is *an* example\n",
           "as_string attribute");
    },
);

done_testing();
