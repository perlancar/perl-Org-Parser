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
    name => 'field_name() (text)',
    doc  => <<'_',
DEADLINE: <2011-06-09 >
DEADLINE <2011-06-09 >
foo
 bar baz : <2011-06-09 >

- item
- item 2: <2011-06-09 >
_
    test_after_parse => sub {
        my (%args) = @_;
        my $doc = $args{result};

        my ($ts1, $ts2, $ts3, $ts4) = $doc->find('Timestamp');
        is( $ts1->field_name, "DEADLINE");
        ok(!$ts2->field_name);
        is( $ts3->field_name, "bar baz");
        is( $ts4->field_name, "item 2");
    },
);

test_parse(
    name => 'field_name() (desc_term)',
    doc  => <<'_',
- name1 :: value
- name2 :: <2011-06-09 >
_
    test_after_parse => sub {
        my (%args) = @_;
        my $doc = $args{result};

        my ($ts1) = $doc->find('Timestamp');
        is( $ts1->field_name, "name2");
    },
);

# TODO
test_parse(
    name => 'field_name() (properties)',
    doc  => <<'_',
* first last
:PROPERTIES:
  :birthday: (5 7 1970)
  :email:    foo@bar.com
:END:
_
    test_after_parse => sub {
        my (%args) = @_;
        my $doc = $args{result};
    },
);

done_testing();
