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
    name => 'non-setting (missing +)',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#TODO: A B | C
_
    num => 0,
);

test_parse(
    name => 'non-setting (not on first column)',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
 #+TODO: A B | C
_
    num => 0,
);

test_parse(
    name => 'setting: syntax error (missing colon)',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+TODO A B | C
_
    dies => 1,
);

test_parse(
    name => 'unknown setting',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+FOO: bar
_
    dies => 1,
);

# also checks case-sensitiveness
test_parse(
    name => 'setting: todo',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+TODO: A B | C C2
#+todo: D
#+Todo: | E
#+tOdO: F G H
_
    num  => 4,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        is($elems->[0]->name, "TODO", "name");
        is_deeply($doc->todo_states, [qw/TODO A B D F G/],
                  "document's todo_states attribute");
        is_deeply($doc->done_states, [qw/DONE C C2 E H/],
                  "document's done_states attribute");
    },
);

test_parse(
    name => 'setting: filetags: argument syntax error',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+FILETAGS: a:
_
    dies => 1,
);

test_parse(
    name => 'setting: filetags',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+FILETAGS:  :tag1:tag2:tag3:
_
    num  => 1,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        is($elems->[0]->name, "FILETAGS", "name");
        is($elems->[0]->raw_arg, ":tag1:tag2:tag3:", "raw_arg");
        is_deeply($elems->[0]->args->{tags}, [qw/tag1 tag2 tag3/],  "tags");
    },
);

test_parse(
    name => 'setting: priorities',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+PRIORITIES: A1 A2 B1 B2 C1 C2
_
    num  => 1,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        is($elems->[0]->name, "PRIORITIES", "name");
        is_deeply($elems->[0]->args->{priorities}, [qw/A1 A2 B1 B2 C1 C2/],
                  "args: priorities");
        is_deeply($doc->priorities, [qw/A1 A2 B1 B2 C1 C2/],
                  "document's priorities attribute");
    },
);

test_parse(
    name => 'setting: drawers',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+DRAWERS: D1 D2
_
    num  => 1,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        is($elems->[0]->name, "DRAWERS", "name");
        is_deeply($elems->[0]->args->{drawers}, [qw/D1 D2/], "args: drawers");
        ok("D1"    ~~ @{$doc->drawers}, "D1 added to list of known drawers");
        ok("D2"    ~~ @{$doc->drawers}, "D2 added to list of known drawers");
        ok("CLOCK" ~~ @{$doc->drawers}, "default drawers still known");
    },
);

#
# block
#

test_parse(
    name => 'unknown block',
    filter_elements => 'Org::Element::Block',
    doc  => <<'_',
#+BEGIN_FOO
bar
#+END_FOO
_
    dies => 1,
);

test_parse(
    name => 'block: BEGIN_EXAMPLE + END_EXAMPLE: undetected (no END)',
    filter_elements => 'Org::Element::Block',
    doc  => <<'_',
#+BEGIN_EXAMPLE
1
2
#+xEND_EXAMPLE
_
    dies => 1,
);

# also checks case-sensitiveness
test_parse(
    name => 'block: BEGIN_EXAMPLE + END_EXAMPLE',
    filter_elements => 'Org::Element::Block',
    doc  => <<'_',
#+BEGIN_EXAMPLE -t -w 40
#+INSIDE
#+end_EXAMPLE
_
    num  => 1,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        is($elems->[0]->name, "EXAMPLE", "name");
        is($elems->[0]->raw_arg, "-t -w 40", "raw_arg");
        is($elems->[0]->raw_content, "#+INSIDE\n", "raw_content");
    },
);

done_testing();

