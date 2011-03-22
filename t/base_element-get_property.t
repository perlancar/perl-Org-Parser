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
    name => 'get_property()',
    doc  => <<'_',
#+PROPERTY: x 1
#+PROPERTY: y 1
* head1
  some text
  :PROPERTIES:
    :x: 2
  :END:
_
    test_after_parse => sub {
        my (%args) = @_;
        my $doc = $args{result};

        my $text = $doc->children->[2]->children->[0];
        is(ref($text), "Org::Element::Text", "got text");
        is($text->as_string, "  some text\n", "got correct text");
        is($text->get_property('x'), 2,
           "text->get_property(x)");
        is($text->get_property('y'), 1,
           "text->get_property(y)");
        ok(!$text->get_property('z'),
           "text->get_property(z)");

        # TODO: search_parent=1
    },
);

done_testing();
