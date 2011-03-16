#!perl -T

use 5.010;
use strict;
use warnings;

use Org::Parser;
use Test::More 0.96;

test_parse_setting(
    name => 'non-setting (missing +)',
    doc  => <<'_',
#TODO: A B | C
_
    num => 0,
);

test_parse_setting(
    name => 'non-setting (not on first column)',
    doc  => <<'_',
 #+TODO: A B | C
_
    num => 0,
);

test_parse_setting(
    name => 'setting: syntax error (missing colon)',
    doc  => <<'_',
#+TODO A B | C
_
    dies => 1,
);

test_parse_setting(
    name => 'unknown setting',
    doc  => <<'_',
#+FOO: bar
_
    dies => 1,
);

test_parse_setting(
    name => 'setting: todo',
    doc  => <<'_',
#+TODO: A B | C C2
#+TODO: D
#+TODO: | E
#+TODO: F G H
_
    num  => 4,
    test_after_parse => sub {
        my ($orgp, $bs) = @_;
        is($bs->[0]{setting}, "TODO", "args: setting");
        is_deeply($orgp->todo_states, [qw/TODO A B D F G/],
                  "parser's todo_states attribute");
        is_deeply($orgp->done_states, [qw/DONE C C2 E H/],
                  "parser's done_states attribute");
    },
);

test_parse_setting(
    name => 'setting: filetags: argument syntax error',
    doc  => <<'_',
#+FILETAGS: a:
_
    dies => 1,
);

test_parse_setting(
    name => 'setting: filetags',
    doc  => <<'_',
#+FILETAGS:  :tag1:tag2:tag3:
_
    num  => 1,
    test_after_parse => sub {
        my ($orgp, $bs) = @_;
        is($bs->[0]{setting}, "FILETAGS", "args: setting");
        is($bs->[0]{raw_arg}, ":tag1:tag2:tag3:", "args: raw_arg");
        is_deeply($bs->[0]{tags}, [qw/tag1 tag2 tag3/],  "args: tags");
    },
);

test_parse_setting(
    name => 'unknown block',
    doc  => <<'_',
#+BEGIN_FOO
bar
#+END_FOO
_
    dies => 1,
);

test_parse_setting(
    name => 'block: BEGIN_EXAMPLE + END_EXAMPLE: undetected (no END)',
    doc  => <<'_',
#+BEGIN_EXAMPLE
1
2
#+xEND_EXAMPLE
_
    dies => 1,
);

test_parse_setting(
    name => 'block: BEGIN_EXAMPLE + END_EXAMPLE',
    doc  => <<'_',
#+BEGIN_EXAMPLE -t -w 40
#+INSIDE
#+END_EXAMPLE
_
    num  => 1,
    test_after_parse => sub {
        my ($orgp, $bs) = @_;
        is($bs->[0]{block}, "EXAMPLE", "args: setting");
        is($bs->[0]{raw_arg}, "-t -w 40", "args: raw_arg");
        is($bs->[0]{raw_content}, "#+INSIDE\n", "args: raw_content");
    },
);

test_parse_setting(
    name => 'setting: priorities',
    doc  => <<'_',
#+PRIORITIES: A1 A2 B1 B2 C1 C2
_
    num  => 1,
    test_after_parse => sub {
        my ($orgp, $bs) = @_;
        is($bs->[0]{setting}, "PRIORITIES", "args: setting");
        is_deeply($bs->[0]{priorities}, [qw/A1 A2 B1 B2 C1 C2/],
                  "args: priorities");
        is_deeply($orgp->priorities, [qw/A1 A2 B1 B2 C1 C2/],
                  "parser's priorities attribute");
    },
);

test_parse_setting(
    name => 'setting: drawers',
    doc  => <<'_',
#+DRAWERS: D1 D2
_
    num  => 1,
    test_after_parse => sub {
        my ($orgp, $bs) = @_;
        is($bs->[0]{setting}, "DRAWERS", "args: setting");
        is_deeply($bs->[0]{drawers}, [qw/D1 D2/],
                  "args: priorities");
        ok("D1" ~~ @{$orgp->drawers}, "D1 added to list of known drawers");
        ok("D2" ~~ @{$orgp->drawers}, "D2 added to list of known drawers");
        ok("CLOCK" ~~ @{$orgp->drawers}, "default drawers still known");
    },
);

done_testing();

sub test_parse_setting {
    my %args = @_;

    subtest $args{name} => sub {
        my @bs;
        my $orgp = Org::Parser->new(
            handler => sub {
                my ($orgp, $ev, $args) = @_;
                return unless $ev eq 'element' &&
                    $args->{element} =~ /^(block|setting)$/;
                push @bs, $args;
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
            is(scalar(@bs), $args{num}, "num=$args{num}");
        }

        if ($args{test_after_parse}) {
            $args{test_after_parse}->($orgp, \@bs);
        }
    };
}
