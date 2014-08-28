#!perl

# check that subsequent parse does not cache the list of todo keywords,
# priorities, etc (due to the use of the /o regex modifier).

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Org::Parser;
use Test::More 0.98;
require "testlib.pl";

subtest "todo keywords" => sub {
    test_parse(
        name => 'parse #1',
        filter_elements => 'Org::Element::Headline',
        doc  => <<'_',
#+TODO: A B | C
* A foo
_
        num => 1,
        test_after_parse => sub {
            my (%args) = @_;
            my $doc    = $args{result};
            my $elems  = $args{elements};
            my $h1 = $elems->[0];

            ok($h1->is_todo);
        },
    );
    test_parse(
        name => 'parse #2',
        filter_elements => 'Org::Element::Headline',
        doc  => <<'_',
#+TODO: D E | F
* D foo
_
        num => 1,
        test_after_parse => sub {
            my (%args) = @_;
            my $doc    = $args{result};
            my $elems  = $args{elements};
            my $h1 = $elems->[0];

            ok($h1->is_todo);
        },
    );
};

subtest "priorities" => sub {
    test_parse(
        name => 'parse #1',
        filter_elements => 'Org::Element::Headline',
        doc  => <<'_',
#+PRIORITIES: A1 A2 B1 B2
* TODO [#A1]
* TODO [#C1]
_
        num => 2,
        test_after_parse => sub {
            my (%args) = @_;
            my $doc    = $args{result};
            my $elems  = $args{elements};
            my $h1 = $elems->[0];
            my $h2 = $elems->[1];

            is($h1->priority, 'A1');
            ok(!$h2->priority);
        },
    );
    test_parse(
        name => 'parse #2',
        filter_elements => 'Org::Element::Headline',
        doc  => <<'_',
#+PRIORITIES: B1 B2 C1 C2
* TODO [#A1]
* TODO [#C1]
_
        num => 2,
        test_after_parse => sub {
            my (%args) = @_;
            my $doc    = $args{result};
            my $elems  = $args{elements};
            my $h1 = $elems->[0];
            my $h2 = $elems->[1];

            ok(!$h1->priority);
            is($h2->priority, 'C1');
        },
    );
};

done_testing();
