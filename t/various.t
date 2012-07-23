#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Org::Parser;
use Test::More 0.96;
require "testlib.pl";

my $NUM_TEST_ITEMS = 4+3+3;

test_parse(
    parse_file_args => ["t/data/various.org"],
    name => 'various',
    test_after_parse => sub {
        my (%args) = @_;
        my $doc    = $args{result};

        my $num_elems;
        my %num_elems;
        $doc->walk(
            sub {
                my $elem = shift;
                my $class = ref($elem);
                $num_elems{$class}++;
                $num_elems++;
            }
        );

        is($num_elems, 41, 'num_elems');
        is($num_elems{"Org::Element::Headline"}, 10, 'num_elems(Headline)');

    },
);

done_testing();
