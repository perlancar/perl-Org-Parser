#!perl -T

use 5.010;
use strict;
use warnings;

sub test_parse {
    my %args = @_;

    subtest $args{name} => sub {
        my @bs;
        my $orgp = Org::Parser->new();
        if ($args{handler}) {
            $orgp->handler($args{handler});
        } elsif ($args{filter_elements}) {
            my ($orgp, $ev, $args) = @_;
            return unless $ev eq 'element' &&
                $args->{element} =~ /^(block|setting)$/;
                push @bs, $args;
            }
        );

        my $res;
        eval {
            $res = $orgp->parse($args{doc});
        };
        my $eval_err = $@;

        if ($args{dies}) {
            ok($eval_err, "dies");
        } else {
            ok(!$eval_err, "doesnt die") or diag("died with msg $eval_err");
        }

        if (defined $args{num}) {
            is(scalar(@bs), $args{num}, "num=$args{num}");
        }

        if ($args{test_after_parse}) {
            $args{test_after_parse}->(parser=>$orgp, result=>$res,
                                      elements=>\@f);
        }
    };
}
