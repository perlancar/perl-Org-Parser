#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Org::Parser;
use Test::More 0.96;
require "testlib.pl";

my $doc = <<'_';
#+TODO: A | B C
 #+TODO: D E | F
_

test_parse(
    parse_args => [$doc],
    name => 'indentable_elements (not indentable)',
    filter_elements => 'Org::Element::Setting',
    num => 1,
);

$doc = <<'_';
#+TBLFM: @2$1=@1$1
 #+tblfm: @3$1=@1$1
_

test_parse(
    parse_args => [$doc],
    name => 'indentable_elements (indentable)',
    filter_elements => 'Org::Element::Setting',
    num => 2,
    test_after_parse => sub {
        my (%args) = @_;
        my $elems = $args{elements};
        is($elems->[1]->indent, " ", "indent attribute");
    },
);

done_testing();
