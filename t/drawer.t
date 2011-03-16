#!perl -T

use 5.010;
use strict;
use warnings;

use Org::Parser;
use Test::More 0.96;

test_parse_drawer(
    name => 'non-drawer (missing end)',
    doc  => <<'_',
* foo
    :CLOCK:
_
    num => 0,
);

test_parse_drawer(
    name => 'non-drawer (extra text before opening line)',
    doc  => <<'_',
* foo
    :CLOCK: extra
    :END:
_
    num => 0,
);

test_parse_drawer(
    name => 'non-drawer (extra text after opening line)',
    doc  => <<'_',
* foo
    extra :CLOCK:
    :END:
_
    num => 0,
);

test_parse_drawer(
    name => 'unknown drawer',
    doc  => <<'_',
* foo
    :FOO:
    :END:
_
    dies => 1,
);

test_parse_drawer(
    name => 'drawer',
    doc  => <<'_',
* foo
    :CLOCK:
text
    :END: extra
_
    num => 1,
    test_after_parse => sub {
        my ($orgp, $drawers) = @_;
        my $d = $drawers->[0];
        is($d->{drawer}, "CLOCK", "args: drawer");
        is($d->{raw_content}, "text\n", "args: raw_content");
    },
);

test_parse_drawer(
    name => 'properties: invalid syntax',
    doc  => <<'_',
    :PROPERTIES:
      :foo:    1
      baz
    :END:
_
    dies => 1,
);

test_parse_drawer(
    name => 'properties',
    doc  => <<'_',
    :PROPERTIES:
      :foo:    1
      :bar: 2
    :END:
_
    num => 1,
    test_after_parse => sub {
        my ($orgp, $drawers) = @_;
        my $d = $drawers->[0];
        is($d->{drawer}, "PROPERTIES", "args: drawer");
        is_deeply($d->{properties}, {foo=>1, bar=>2}, "args: properties");
    },
);

done_testing();

sub test_parse_drawer {
    my %args = @_;

    subtest $args{name} => sub {
        my @drawers;
        my $orgp = Org::Parser->new(
            handler => sub {
                my ($orgp, $ev, $args) = @_;
                return unless $ev eq 'element' &&
                    $args->{element} eq 'drawer';
                push @drawers, $args;
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
            is(scalar(@drawers), $args{num}, "num=$args{num}");
        }

        if ($args{test_after_parse}) {
            $args{test_after_parse}->($orgp, \@drawers);
        }
    };
}
