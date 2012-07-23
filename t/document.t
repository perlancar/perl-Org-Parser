#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Module::Loaded;
use Org::Document;
use Test::More 0.96;
require "testlib.pl";

plan skip_all_if => 'Org::Element::Comment already loaded'
    if is_loaded('Org::Element::Comment');

my $doc = Org::Document->new;
$doc->load_element_modules;
ok(is_loaded('Org::Element::Comment'), 'Org::Element::Comment loaded');

done_testing();
