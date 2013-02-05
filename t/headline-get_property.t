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
    filter_elements => 'Org::Element::Headline',
    doc  => <<'_',
#+PROPERTY: x 1
#+PROPERTY: y 1
* head1
  some text
  :PROPERTIES:
    :x: 2
    :p: 4
  :END:
** head2
  some text
  :PROPERTIES:
    :z: 3
  :END:
  :LOGBOOK:
    :z: 5
  :END:

_
    num => 2,
    test_after_parse => sub {
        my (%args) = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        my $h1 = $elems->[0];
        my $h2 = $elems->[1];

        is($h1->get_property('x'), 2, "h1->get_property(x)");
        is($h2->get_property('z'), 3, "h2->get_property(z)");
        is($h2->get_drawer("LOGBOOK")->properties->{'z'}, 5, "h2->get_drawer(LOGBOOK) z=5");
        ok(!$h1->get_property('z'), "h1->get_property(z)");
        return;
        is($h1->get_property('y'), 1, "h1->get_property(y)");
        ok(!$h2->get_property('p'), "h2->get_property(p) (search_parent=0)");
        is($h2->get_property('p', 1), 4,
           "h2->get_property(p) (search_parent=1)");

        # TODO: search_parent=1
    },
);

done_testing();
