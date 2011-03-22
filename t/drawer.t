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
    name => 'non-drawer (missing end)',
    filter_elements => 'Org::Element::Drawer',
    doc  => <<'_',
* foo
    :CLOCK:
_
    num => 0,
);

test_parse(
    name => 'non-drawer (extra text before opening line)',
    filter_elements => 'Org::Element::Drawer',
    doc  => <<'_',
* foo
    :CLOCK: extra
    :END:
_
    num => 0,
);

test_parse(
    name => 'non-drawer (extra text after opening line)',
    filter_elements => 'Org::Element::Drawer',
    doc  => <<'_',
* foo
    extra :CLOCK:
    :END:
_
    num => 0,
);

test_parse(
    name => 'unknown drawer name',
    filter_elements => 'Org::Element::Drawer',
    doc  => <<'_',
* foo
    :FOO:
    :END:
_
    dies => 1,
);

test_parse(
    name => 'properties basic tests',
    filter_elements => 'Org::Element::Drawer',
    doc  => <<'_',
    :PROPERTIES:
      :foo: 1 "2 3"
      :bar: 2
    :END:
_
    num => 1,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        my $d = $elems->[0];
        is($d->name, "PROPERTIES", "name");
        is_deeply($d->properties, {foo=>[1, "2 3"], bar=>2}, "properties");
    },
);

done_testing();
