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
    name => 'non-headline (missing space)',
    filter_elements => 'Org::Element::Headline',
    doc  => <<'_',
*h
_
    num => 0,
);

test_parse(
    name => 'non-headline (not on first column)',
    filter_elements => 'Org::Element::Headline',
    doc  => <<'_',
 * h
_
    num => 0,
);

test_parse(
    name => 'non-headline (no title)',
    filter_elements => 'Org::Element::Headline',
    doc  => <<'_',
*
_
    num => 0,
);

test_parse(
    name => 'headline basic tests',
    filter_elements => 'Org::Element::Headline',
    doc  => <<'_',
*   h1 1
** h2 1 :tag1:tag2:
*** h3 1
text
*** TODO [#A] h3 2
    text
** DONE h2 2
* h1 2
_
    num => 6,
    test_after_parse => sub {
        my (%args) = @_;
        my $elems = $args{elements};
        is($elems->[0]->title->as_string, "  h1 1", "0: title not trimmed");
        is($elems->[0]->level, 1, "0: level");

        is($elems->[1]->title->as_string, "h2 1", "1: title");
        is($elems->[1]->level, 2, "1: level");
        is_deeply($elems->[1]->tags, ['tag1', 'tag2'], "1: tags");

        is($elems->[2]->title->as_string, "h3 1", "2: title");
        is($elems->[2]->level, 3, "2: level");

        is( $elems->[3]->title->as_string, "h3 2", "3: title");
        is( $elems->[3]->level, 3, "3: level");
        is( $elems->[3]->is_todo, 1, "3: is_todo");
        ok(!$elems->[3]->is_done, "3: is_done");
        is( $elems->[3]->todo_state, "TODO", "3: todo_state");
        is( $elems->[3]->todo_priority, "A", "3: todo_priority");

        is($elems->[4]->title->as_string, "h2 2", "4: title");
        is($elems->[4]->level, 2, "4: level");
        is($elems->[4]->is_todo, 1, "4: is_todo");
        is($elems->[4]->is_done, 1, "4: is_done");
        is($elems->[4]->todo_state, "DONE", "4: todo_state");
        # XXX default priority

        is($elems->[5]->title->as_string, "h1 2", "5: title");
        is($elems->[5]->level, 1, "5: level");
    },
);

test_parse(
    name => 'todo keyword is case sensitive',
    filter_elements => sub { $_[0]->isa('Org::Element::Headline') &&
                                 $_[0]->is_todo },
    doc  => <<'_',
* TODO 1
* Todo 2
* todo 3
* toDO 4
_
    num => 1,
);

test_parse(
    name => 'todo keyword can be separated by other \W aside from \s',
    filter_elements => sub { $_[0]->isa('Org::Element::Headline') &&
                                 $_[0]->is_todo },
    doc  => <<"_",
* TODO   1
* TODO\t2
* TODO+3a
* TODO+  3b
* TODO/4a
* TODO//4b

* TODO5a
* TODO_5b
_
    num => 6,
    test_after_parse => sub {
        my (%args) = @_;
        my $elems = $args{elements};
        is($elems->[0]->title->as_string, "1", "title 1");
        is($elems->[1]->title->as_string, "2", "title 2");
        is($elems->[2]->title->as_string, "+3a", "title 3");
        is($elems->[3]->title->as_string, "+  3b", "title 4");
        is($elems->[4]->title->as_string, "/4a", "title 5");
        is($elems->[5]->title->as_string, "//4b", "title 6");
    },
);

test_parse(
    name => 'inline elements in headline title',
    filter_elements => 'Org::Element::Headline',
    doc  => <<'_',
* this headline contains timestamp <2011-03-17 > as well as text
_
    num => 1,
    test_after_parse => sub {
        my (%args) = @_;
        my $elems = $args{elements};
        my $hl    = $elems->[0];
        my $title = $hl->title;
        isa_ok($title->children->[0], "Org::Element::Text");
        isa_ok($title->children->[1], "Org::Element::ScheduleTimestamp");
        isa_ok($title->children->[2], "Org::Element::Text");
    },
);

done_testing();
