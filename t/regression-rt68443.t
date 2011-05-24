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
    name => 'regression test RT#68443',
    filter_elements => 'Org::Element::Table',
    doc  => <<'_',
* test
  | some text in a table | column |
  |----------------------+--------|
  |                      |        |
  something outside a table
_
    num => 1,
);

done_testing();
