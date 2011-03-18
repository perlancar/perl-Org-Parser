#!perl -T

use 5.010;
use strict;
use warnings;

sub test_parse {
    my %args = @_;

    my $fe = $args{filter_elements};

    subtest $args{name} => sub {
        my @elems;
        my $orgp = Org::Parser->new();
        if ($args{handler}) {
            $orgp->handler($args{handler});
        } elsif ($fe) {
            $orgp->handler(
                sub {
                    my ($orgp, $ev, $args) = @_;
                    return unless $ev eq 'element';
                    my $el     = $args->{element};
                    my $eltype = ref($el);
                    my $fetype = ref($fe);
                    if ($fetype eq 'Regexp') {
                        return unless $eltype =~ $args{filter_elements};
                    } elsif ($fetype eq 'CODE')  {
                        return unless $fe->($el);
                    } elsif (!$fetype) {
                        return unless $eltype eq $args{filter_elements};
                    } else {
                        die "BUG: filter_elements cannot be a $fetype";
                    }
                    push @elems, $el;
                });
        }

        my $res;
        eval {
            if ($args{doc}) {
                $res = $orgp->parse($args{doc});
            } elsif ($args{parse_args}) {
                $res = $orgp->parse(@{ $args{parse_args} });
            } elsif ($args{parse_file_args}) {
                $res = $orgp->parse_file(@{ $args{parse_file_args} });
            } else {
                die "Either doc/parse_args/parse_file_args must be specified";
            }
        };
        my $eval_err = $@;

        if ($args{dies}) {
            ok($eval_err, "dies");
        } else {
            ok(!$eval_err, "doesnt die") or diag("died with msg $eval_err");
        }

        if (defined $args{num}) {
            is(scalar(@elems), $args{num}, "num=$args{num}");
        }

        if ($args{test_after_parse}) {
            $args{test_after_parse}->(parser=>$orgp, result=>$res,
                                      elements=>\@elems);
        }
    };
}

1;
