package Org::Element::Block;
# ABSTRACT: Represent Org block

use 5.010;
use strict;
use warnings;

use Org::Element::Text;

use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 name => OBJ

Block name. For example, #+begin_src ... #+end_src is an 'SRC' block.

=cut

has name => (is => 'rw');

=head2 raw_arg => STR

Argument of block. For example:

 #+BEGIN_EXAMPLE -t -w40
 ...
 #+END_EXAMPLE

will have '-t -w40' as the raw_arg value.

=cut

has raw_arg => (is => 'rw');

=head2 raw_content => STR

Content of block. In the previous 'raw_arg' example, 'raw_content' is "...\n".

=cut

has raw_content => (is => 'rw');


=head1 METHODS

=head2 new(raw => STR, parser => OBJ)

Create a new headline item from parsing raw string. (You can also create
directly by filling out priority, title, etc).

=cut

sub BUILD {
    my ($self, $args) = @_;
    my $raw = $args->{raw};
    my $doc = $self->document;
    if (defined $raw) {
        state $re = qr/\A\#\+(?:BEGIN_(
                               ASCII|CENTER|COMMENT|EXAMPLE|HTML|
                               LATEX|QUOTE|SRC|VERSE
                       ))
                       (?:\s+(\S.*))\R # arg
                       ((?:.|\R)*)     # content
                       \#\+\w+\R?\z    # closing
                      /xi;
        $raw =~ $re or die "Unknown block or invalid syntax: $raw";
        $self->handler->($self, "element", {
            element=>"block", block=>uc($1),
            raw_arg=>$2//"", raw_content=>$3,
        raw=>$raw});
}

        state $re = qr/\A(\*+)\s(.*?)(?:\s+($Org::Parser::tags_re))?\s*\R?\z/x;
        $raw =~ $re or die "Invalid headline syntax: $raw";
        $self->_raw($raw);
        my ($bullet, $title, $tags) = ($1, $2, $3);
        $self->level(length($bullet));
        $self->tags(Org::Parser::__split_tags($tags)) if $tags;

        # XXX cache re
        my $todo_kw_re = "(?:".
            join("|", map {quotemeta}
                     @{$doc->todo_states}, @{$doc->done_states}) . ")";
        if ($title =~ s/^($todo_kw_re)\s+//) {
            my $state = $1;
            $self->is_todo(1);
            $self->todo_state($state);
            $self->is_done(1) if $state ~~ @{ $doc->done_states };

            my $prio_re = "(?:".
                join("|", map {quotemeta} @{$doc->priorities}) . ")";
            if ($title =~ s/\[#($prio_re)\]\s*//) {
                $self->priority($1);
            }
        }

        $self->title(Org::Element::Text->new(raw => $title, document=>$doc));
    }
}

sub as_string {
    my ($self) = @_;

}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
