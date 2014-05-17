#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use File::Temp qw/tempfile/;
use File::Slurp::Tiny qw(write_file);
use Org::Parser;
use Test::Exception;
use Test::More 0.96;
require "testlib.pl";

my $doc = <<_;
#+TODO: A B | C
* test1
** test11
* test2
_
my $ary = [split /(?<=\n)/, $doc];
sub org {
    state $ary2 = [@$ary];
    shift @$ary2;
}

test_parse(
    name       => "parse() accepts str",
    parse_args => [$doc],
);
test_parse(
    name       => "parse() accepts arrayref",
    parse_args => [$ary],
);
test_parse(
    name       => "parse() accepts coderef",
    parse_args => [\&org],
);
my ($fh, $filename) = tempfile();
write_file($filename, $doc);
open $fh, "<", $filename;
test_parse(
    name       => "parse() accepts filehandle",
    parse_args => [$fh],
);
test_parse(
    name            => "parse_file() accepts file name",
    parse_file_args => [$filename],
);

test_parse(
    name       => "parse() doesnt accept hashref",
    parse_args => [{}],
    dies       => 1,
);
test_parse(
    name       => "parse() requires argument",
    parse_args => [],
    dies       => 1,
);
test_parse(
    name       => "parse() requires defined argument",
    parse_args => [undef],
    dies       => 1,
);

test_parse(
    name => "parse() returns Org::Document instance",
    doc  => "* test\n",
    test_after_parse => sub {
        my %args = @_;
        my $doc = $args{result};
        isa_ok($doc, "Org::Document");
    },
);

subtest "parse_file: cache_file option" => sub {
    my $orgp = Org::Parser->new;
    my ($fhc, $filenamec) = tempfile();
    sleep 2;
    my ($fh1, $filename1) = tempfile();
    write_file($filename1, "[2012-07-99 ]");
    my ($fh2, $filename2) = tempfile();
    write_file($filename2, "test");
    lives_ok { $orgp->parse_file($filename2, {cache_file=>$filenamec}) };
    rename $filename1, $filename2;
    lives_ok { $orgp->parse_file($filename2, {cache_file=>$filenamec}) }
        'cached result still used';
    sleep 2;
    write_file($filename2, "[2012-07-99 ]");
    dies_ok { $orgp->parse_file($filename2, {cache_file=>$filenamec}) }
        'file parsed again';
};

done_testing();
