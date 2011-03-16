#!perl -T

use 5.010;
use strict;
use warnings;

use Org::Parser;
use Test::More 0.96;

# accepts str
# accepts arrayref
# accepts coderef
# accepts filehandle/glob

test_parse();

sub test_parse {
    my %args = @_;
    my $orgp = Org::Parser->new;


}
