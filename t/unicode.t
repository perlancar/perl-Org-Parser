#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Org::Parser;
use Test::Exception;
use Test::More 0.96;

for (glob "t/data/unicode/*.org") {
    lives_ok { Org::Parser->parse_file($_) } "can parse $_";
}

done_testing();
