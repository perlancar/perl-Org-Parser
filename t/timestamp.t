#!perl -T

use 5.010;
use strict;
use warnings;

use DateTime;
use Org::Parser;
use Test::More 0.96;

test_parse_timestamp(
    name => 'schedule timestamp',
    doc  => <<'_',
* TODO foo
  SCHEDULED: <2011-03-16 Tue>
  TEST: <2011-03-16 >
  TEST: <2011-03-16 Tue 01:23>
_
    num => 3,
    test_after_parse => sub {
        my ($orgp, $ts) = @_;
        is($ts->[0]{element}, "schedule timestamp", "args: element");
        is(DateTime->compare(DateTime->new(year=>2011, month=>3, day=>16),
                             $ts->[0]{timestamp}),
           0, "args: timestamp");
    },
);


done_testing();

sub test_parse_timestamp {
    my %args = @_;

    subtest $args{name} => sub {
        my @ts;
        my $orgp = Org::Parser->new(
            handler => sub {
                my ($orgp, $ev, $args) = @_;
                return unless $ev eq 'element' &&
                    $args->{element} =~ /timestamp/;
                push @ts, $args;
            }
        );

        eval {
            $orgp->parse($args{doc});
        };
        my $eval_err = $@;

        if ($args{dies}) {
            ok($eval_err, "dies");
        } else {
            ok(!$eval_err, "doesnt die") or diag("died with msg $eval_err");
        }

        if (defined $args{num}) {
            is(scalar(@ts), $args{num}, "num=$args{num}");
        }

        if ($args{test_after_parse}) {
            $args{test_after_parse}->($orgp, \@ts);
        }
    };
}
