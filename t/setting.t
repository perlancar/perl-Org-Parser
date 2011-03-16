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
    name => 'syntax error (missing colon)',
    doc  => <<'_',
#+TODO A B | C
_
    dies => 1,
);

test_parse_setting(
    name => 'unknown single-line setting',
    doc  => <<'_',
#+FOO: bar
_
    dies => 1,
);

test_parse_setting(
    name => 'todo',
    doc  => <<'_',
#+TODO: A B | C C2
#+TODO: D
#+TODO: | E
#+TODO: F G H
_
    num  => 4,
    test_after_parse => sub {
        my ($orgp, $settings) = @_;
        is($settings->[0]{setting}, "TODO", "args: setting");
        is_deeply($orgp->todo_states, [qw/TODO A B D F G/],
                  "parser's todo_states attribute");
        is_deeply($orgp->done_states, [qw/DONE C C2 E H/],
                  "parser's done_states attribute");
    },
);

test_parse_setting(
    name => 'filetags: argument syntax error',
    doc  => <<'_',
#+FILETAGS: a:
_
    dies => 1,
);

test_parse_setting(
    name => 'filetags',
    doc  => <<'_',
#+FILETAGS:  :tag1:tag2:tag3:
_
    num  => 1,
    test_after_parse => sub {
        my ($orgp, $settings) = @_;
        is($settings->[0]{setting}, "FILETAGS", "args: setting");
        is($settings->[0]{raw_arg}, ":tag1:tag2:tag3:", "args: raw_arg");
        is_deeply($settings->[0]{tags}, [qw/tag1 tag2 tag3/],  "args: tags");
    },
);

test_parse_setting(
    name => 'unknown multi-line setting',
    doc  => <<'_',
#+BEGIN_FOO
bar
#+END_FOO
_
    dies => 1,
);

test_parse_setting(
    name => 'multiline: BEGIN_EXAMPLE + END_EXAMPLE: undetected (no END)',
    doc  => <<'_',
#+BEGIN_EXAMPLE
1
2
#+xEND_EXAMPLE
_
    dies => 1,
);

test_parse_setting(
    name => 'multiline: BEGIN_EXAMPLE + END_EXAMPLE',
    doc  => <<'_',
#+BEGIN_EXAMPLE -t -w 40
#+INSIDE
#+END_EXAMPLE
_
    num  => 1,
    test_after_parse => sub {
        my ($orgp, $settings) = @_;
        is($settings->[0]{setting}, "EXAMPLE", "args: setting");
        is($settings->[0]{raw_arg}, "-t -w 40", "args: raw_arg");
        is($settings->[0]{raw_content}, "#+INSIDE\n", "args: raw_content");
    },
);

test_parse_setting(
    name => 'priorities',
    doc  => <<'_',
#+PRIORITIES: A1 A2 B1 B2 C1 C2
_
    num  => 1,
    test_after_parse => sub {
        my ($orgp, $settings) = @_;
        is($settings->[0]{setting}, "PRIORITIES", "args: setting");
        is_deeply($settings->[0]{priorities}, [qw/A1 A2 B1 B2 C1 C2/],
                  "args: priorities");
        is_deeply($orgp->priorities, [qw/A1 A2 B1 B2 C1 C2/],
                  "parser's priorities attribute");
    },
);

done_testing();

sub test_parse_setting {
    my %args = @_;

    subtest $args{name} => sub {
        my @settings;
        my $orgp = Org::Parser->new(
            handler => sub {
                my ($orgp, $ev, $args) = @_;
                return unless $ev eq 'element' && $args->{element} eq 'setting';
                push @settings, $args;
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
            is(scalar(@settings), $args{num}, "num=$args{num}");
        }

        if ($args{test_after_parse}) {
            $args{test_after_parse}->($orgp, \@settings);
        }
    };
}
