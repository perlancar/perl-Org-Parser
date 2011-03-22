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
    name => 'setting: syntax error (missing colon, becomes comment)',
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
        is($elems->[0]->args->[0], ":tag1:tag2:tag3:", "args[0]");
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
        is_deeply($elems->[0]->args, [qw/A1 A2 B1 B2 C1 C2/],
                  "args");
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
        ok("D1"    ~~ @{$doc->drawer_names}, "D1 added to list of known drawers");
        ok("D2"    ~~ @{$doc->drawer_names}, "D2 added to list of known drawers");
        ok("CLOCK" ~~ @{$doc->drawer_names}, "default drawers still known");
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
    name => 'block: EXAMPLE: undetected (no END, becomes comment)',
    filter_elements => 'Org::Element::Block',
    doc  => <<'_',
#+BEGIN_EXAMPLE
1
2
#+xEND_EXAMPLE
_
    dies => 0,
    num => 0,
);

# also checks case-sensitiveness
test_parse(
    name => 'block: EXAMPLE basic tests',
    filter_elements => 'Org::Element::Block',
    doc  => <<'_',
#+BEGIN_EXAMPLE -t -w 40
#+INSIDE
line 2
#+end_EXAMPLE
_
    num  => 1,
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        my $elems = $args{elements};
        my $bl = $elems->[0];
        is($bl->name, "EXAMPLE", "name");
        is_deeply($bl->args, ["-t", "-w", 40], "args");
        is($bl->raw_content, "#+INSIDE\nline 2", "raw_content");
    },
);

done_testing();

