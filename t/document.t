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

subtest "cmp_priorities()" => sub {
    my $doc = Org::Document->new(from_string=>'');
    is($doc->cmp_priorities('A','A'), 0);
    is($doc->cmp_priorities('A','B'), -1);
    is($doc->cmp_priorities('B','A'), 1);
    ok(!defined($doc->cmp_priorities('B','X')));
    ok(!defined($doc->cmp_priorities('X','A')));
    ok(!defined($doc->cmp_priorities('X','X')));

    $doc = Org::Document->new(from_string=>"#+PRIORITIES: A X B\n");
    is($doc->cmp_priorities('A','A'), 0);
    is($doc->cmp_priorities('X','X'), 0);
    is($doc->cmp_priorities('A','X'), -1);
    is($doc->cmp_priorities('B','X'), 1);
    ok(!defined($doc->cmp_priorities('A','C')));
};

done_testing();
