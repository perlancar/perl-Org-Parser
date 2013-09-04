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
    name => 'list clock tests',
    parse_file_args => ["t/data/listitemclock.org"],
    filter_elements => 'Org::Element::TimeRange',
    num => 3,
    test_after_parse => sub {
        my (%args) = @_;
        my $elems = $args{elements};
        my $res = $args{result};

        print Org::Dump::dump_element($args{result});
        
        # make sure each clock entry is a child of the headline, not the list items
        foreach my $e (@$elems) {
            is(ref $e->parent, "Org::Element::Headline",
               "clock entries should be children of headline, not listitem");
            is($e->field_name(), "CLOCK", "check for clock tag");
        }

        # make sure list items are broken into separate lists
        my $kids = $args{result}->children->[0];
        is($kids->children->[0]->as_string, 'CLOCK: ',
           "first child is clock entry");
        is(ref $kids->children->[1], 'Org::Element::TimeRange',
           "next one is the time range");
        is(ref $kids->children->[3], 'Org::Element::List',
           "after that should be a list");
        is($#{$kids->children->[3]->children}, 1,
           "list has one entry");
        is($kids->children->[3]->children->[0]->as_string, "- here is a list\n",
           "");
        is(ref $kids->children->[3]->children->[1], "Org::Element::List",
           "under that is a sub-list");
        is($#{$kids->children->[3]->children->[1]->children}, 2,
           "... with three entries");

        # TBD check second list

        return;
    },
);

done_testing();
