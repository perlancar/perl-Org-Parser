#!perl -T

use 5.010;
use strict;
use warnings;

use File::Temp qw/tempfile/;
use File::Slurp;
use Org::Parser;
use Test::More 0.96;

# accepts str
# accepts arrayref
# accepts coderef
# accepts filehandle/glob

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
    name  => "parse() accepts str",
    parse => [$doc],
);
test_parse(
    name  => "parse() accepts arrayref",
    parse => [$ary],
);
test_parse(
    name  => "parse() accepts coderef",
    parse => [\&org],
);
my ($fh, $filename) = tempfile();
write_file($filename, $doc);
open $fh, "<", $filename;
test_parse(
    name  => "parse() accepts filehandle",
    parse => [$fh],
);
test_parse(
    name       => "parse_file() accepts file name",
    parse_file => [$filename],
);

test_parse(
    name  => "parse() doesnt accept hashref",
    parse => [{}],
    dies  => 1,
);
test_parse(
    name  => "parse() requires argument",
    parse => [],
    dies  => 1,
);
test_parse(
    name  => "parse() requires defined argument",
    parse => [undef],
    dies  => 1,
);

done_testing();

sub test_parse {
    my %args = @_;
    my $orgp;

    subtest $args{name} => sub {
        if ($args{parser_args}) {
            $orgp = Org::Parser->new(%{ $args{parser_args} });
        } else {
            $orgp = Org::Parser->new;
        }

        eval {
            if ($args{parse}) {
                $orgp->parse(@{ $args{parse} });
            } elsif ($args{parse_file}) {
                $orgp->parse_file(@{ $args{parse_file} });
            } else {
                die "BUG: either parse or parse_file must be specified";
            }
        };
        my $eval_err = $@;

        if ($args{dies}) {
            ok($eval_err, "dies");
        } else {
            ok(!$eval_err, "doesnt die") or diag("died with msg $eval_err");
        }
    };
}
