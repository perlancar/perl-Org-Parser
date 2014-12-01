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
*** head3
 some text
 :PROPERTIES:
  :z: 6
 :END:
_
    num => 3,
    test_after_parse => sub {
        my (%args) = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        my $h1 = $elems->[0];
        my $h2 = $elems->[1];
        my $h3 = $elems->[2];

        is($h1->get_property('x'), 2, "h1->get_property(x)"); # from own
        is($h1->get_property('y'), 1, "h1->get_property(y)"); # from file-wide property
        ok(!$h1->get_property('z'), "h1->get_property(z)"); # not found

        is($h2->get_property('z'), 3, "h2->get_property(z)"); # from own
        is($h2->get_drawer("LOGBOOK")->properties->{'z'}, 5, "h2->get_drawer(LOGBOOK) z=5"); # from a named drawer other than PROPERTIES
        ok(!$h2->get_property('p'), "h2->get_property(p)"); # not found
        is($h2->get_property('p', 1), 4, "h2->get_property(p,1)"); # from parent
        is($h2->get_property('y'), 1, "h2->get_property(y)"); # from file-wide property

        is($h3->get_property('z'), 6, "h3->get_property(z)"); # from own
        is($h3->get_property('x', 1), 2, "h3->get_property(x,1)"); # from grand-parent

    },
);

done_testing();
