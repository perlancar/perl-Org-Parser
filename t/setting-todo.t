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
    parse_file_args => ["t/data/custom_todo_kw.org"],
    name => 'setting: TODO',
    filter_elements => 'Org::Element::Headline',
    num => 3 + $NUM_TEST_ITEMS,
    test_after_parse => sub {
        my (%args) = @_;
        my $elems = $args{elements};
        my $num_test_items = 0;

        for my $el (@$elems) {
            my $title = $el->title->as_string;
            my $re = qr/(?: (?:([A-Z]+)=([^;]*)) (?:;\s|\z) )/x;
            my $h = $el->as_string; $h =~ s/\R.*//s;
            #diag "heading='$h', ".
            #    "is_todo=".($el->is_todo//0).", is_done=".($el->is_done//0);
            next unless $title =~ /$re/;
            $num_test_items++;
            my %v;
            while ($title =~ s/$re//) { $v{$1} = $2 }
            #diag explain \%v;
            if ($v{RES} =~ /todo/) {
                ok( $el->is_todo, "#$num_test_items is a todo ($v{NOTE})");
            } else {
                ok(!$el->is_todo, "#$num_test_items not a todo ($v{NOTE})");
            }
            if ($v{RES} =~ /done/) {
                ok( $el->is_done, "#$num_test_items is a done ($v{NOTE})");
            } else {
                ok(!$el->is_done, "#$num_test_items not a done ($v{NOTE})");
            }
        }

        is($num_test_items, $NUM_TEST_ITEMS, "num_test_items");
    },
);

done_testing();
