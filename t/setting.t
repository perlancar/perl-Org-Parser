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
    name => 'syntax error (missing colon, becomes comment)',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+TODO A B | C
_
    dies => 0,
    num => 0,
);

test_parse(
    name => 'unknown setting',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+FOO: bar
_
    dies => 1,
);

test_parse(
    name => 'FILETAGS: argument syntax error',
    filter_elements => 'Org::Element::Setting',
    doc  => <<'_',
#+FILETAGS: a:
_
    dies => 1,
);

test_parse(
    name => 'FILETAGS: basic tests',
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
        is($elems->[0]->args->[0], ":tag1:tag2:tag3:", "args[0]");
    },
);

test_parse(
    name => 'PRIORITIES: basic tests',
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
        is_deeply($elems->[0]->args, [qw/A1 A2 B1 B2 C1 C2/],
                  "args");
        is_deeply($doc->priorities, [qw/A1 A2 B1 B2 C1 C2/],
                  "document's priorities attribute");
    },
);

test_parse(
    name => 'DRAWERS: basic tests',
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
        ok("D1"    ~~ @{$doc->drawer_names},
           "D1 added to list of known drawers");
        ok("D2"    ~~ @{$doc->drawer_names},
           "D2 added to list of known drawers");
        ok("CLOCK" ~~ @{$doc->drawer_names},
           "default drawers still known");
    },
);

test_parse(
    name => 'indentable_elements (not indentable)',
    filter_elements => 'Org::Element::Setting',
    doc => <<'_',
#+TODO: A | B C
 #+TODO: D E | F
_
    num => 1,
);
test_parse(
    name => 'indentable_elements (not indentable, test text)',
    filter_elements => 'Org::Element::Text',
    doc => <<'_',
#+TODO: A | B C
 #+TODO: D E | F
_
    num => 1,
    test_after_parse => sub {
        my (%args) = @_;
        my $elems = $args{elements};
        is($elems->[0]->as_string, " #+TODO: D E | F\n", "text");
    },
);

test_parse(
    name => 'indentable_elements (indentable)',
    filter_elements => 'Org::Element::Setting',
    doc => <<'_',
#+TBLFM: @2$1=@1$1
 #+tblfm: @3$1=@1$1
_
    num => 2,
    test_after_parse => sub {
        my (%args) = @_;
        my $elems = $args{elements};
        is($elems->[1]->indent, " ", "indent attribute");
    },
);

done_testing();
