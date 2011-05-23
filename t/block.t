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
    name => 'EXAMPLE: undetected (no END, becomes comment)',
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
    name => 'EXAMPLE: basic tests',
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
