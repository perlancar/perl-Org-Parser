#!perl -T

use 5.010;
use strict;
use warnings;

use Org::Parser;
use Test::More 0.96;

test_parse_headline(
    name => 'non-headline (missing space)',
    doc  => <<'_',
*h
_
    num => 0,
);

test_parse_headline(
    name => 'non-headline (not on first column)',
    doc  => <<'_',
 * h
_
    num => 0,
);

test_parse_headline(
    name => 'non-headline (no title)',
    doc  => <<'_',
*
_
    num => 0,
);

test_parse_headline(
    name => 'headline',
    doc  => <<'_',
*   h1 1
** h2 1 :tag1:tag2:
*** h3 1
text
*** TODO [#A] h3 2
    text
** DONE h2 2
* h1 2
_
    num => 6,
    test_after_parse => sub {
        my ($orgp, $headlines) = @_;
        is($headlines->[0]{title}, "h1 1", "0: title trimming");
        is($headlines->[0]{level}, 1, "0: level");

        is($headlines->[1]{title}, "h2 1", "1: title");
        is($headlines->[1]{level}, 2, "1: level");
        is_deeply($headlines->[1]{tags}, ['tag1', 'tag2'], "1: tags");

        is($headlines->[2]{title}, "h3 1", "2: title");
        is($headlines->[2]{level}, 3, "2: level");

        is( $headlines->[3]{title}, "h3 2", "3: title");
        is( $headlines->[3]{level}, 3, "3: level");
        is( $headlines->[3]{is_todo}, 1, "3: is_todo");
        ok(!$headlines->[3]{is_done}, "3: is_done");
        is( $headlines->[3]{todo_state}, "TODO", "3: todo_state");
        is( $headlines->[3]{todo_priority}, "A", "3: todo_priority");

        is($headlines->[4]{title}, "h2 2", "4: title");
        is($headlines->[4]{level}, 2, "4: level");
        is($headlines->[4]{is_todo}, 1, "4: is_todo");
        is($headlines->[4]{is_done}, 1, "4: is_done");
        is($headlines->[4]{todo_state}, "DONE", "4: todo_state");
        # XXX default priority

        is($headlines->[5]{title}, "h1 2", "5: title");
        is($headlines->[5]{level}, 1, "5: level");
    },
);

done_testing();

sub test_parse_headline {
    my %args = @_;

    subtest $args{name} => sub {
        my @headlines;
        my $orgp = Org::Parser->new(
            handler => sub {
                my ($orgp, $ev, $args) = @_;
                return unless $ev eq 'element' &&
                    $args->{element} eq 'headline';
                push @headlines, $args;
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
            is(scalar(@headlines), $args{num}, "num=$args{num}");
        }

        if ($args{test_after_parse}) {
            $args{test_after_parse}->($orgp, \@headlines);
        }
    };
}
