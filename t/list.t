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
    parse_file_args => ["t/data/listitem.org"],
    name => 'list tests',
    filter_elements => 'Org::Element::ListItem',
    num => 15,
    test_after_parse => sub {
        my (%args) = @_;
        my $elems = $args{elements};

        my $i=0;
        is($elems->[$i]->parent->indent, " "x2, "item[$i]->list->indent");
        is($elems->[$i]->bullet, "-", "item[$i]->bullet");
        is($elems->[$i]->parent->type, "U", "item[$i]->list->type");

        $i=6;
        is($elems->[$i]->parent->type, "D", "item[$i]->list->type");

        $i=7;
        is($elems->[$i]->check_state, "X", "item[$i]->check_state");
        # TODO: only check_states " ", "X", "-" are valid

        $i=9;
        is($elems->[$i]->parent->indent, " "x8, "item[$i]->list->indent");
        is($elems->[$i]->bullet, "1.", "item[$i]->bullet");
        is($elems->[$i]->parent->type, "O", "item[$i]->list->type");

        # XXX the rest of 1..14
    },
);

done_testing();
