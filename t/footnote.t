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
    name => 'footnote basic tests',
    filter_elements => 'Org::Element::Footnote',
    doc  => <<'_',
# footnotes

 [1]
[fn:a]
[fn:b:inline definition]
[fn:c] definition
[fn::anon inline definition]

# non-footnotes

[fn:name
with newline]

[fn:name:definition
with newline]
_
    num => 5,
    test_after_parse => sub {
        my %args  = @_;
        my $doc   = $args{result};
        my $fn = $args{elements};

        is( $fn->[0]->name, 1, "fn0 name");
        ok( $fn->[0]->is_ref, "fn0 is ref");
        ok(!$fn->[0]->def, "fn0 no def");

        is( $fn->[1]->name, "a", "fn1 name");
        ok( $fn->[1]->is_ref, "fn1 is ref");
        ok(!$fn->[1]->def, "fn1 no def");

        is( $fn->[2]->name, "b", "fn2 name");
        ok(!$fn->[2]->is_ref, "fn2 not ref");
        is( $fn->[2]->def->as_string, "inline definition", "fn2 def");

        is( $fn->[3]->name, "c", "fn3 name");
        ok(!$fn->[3]->is_ref, "fn3 not ref");
        is( $fn->[3]->def->as_string, "definition", "fn3 def");

        ok(!$fn->[4]->name, "fn4 anon");
        ok( $fn->[4]->is_ref, "fn4 is ref");
        is( $fn->[4]->def->as_string, "anon inline definition", "fn4 def");
    },
);

done_testing();

