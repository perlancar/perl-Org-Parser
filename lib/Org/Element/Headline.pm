package Org::Element::Headline;
# ABSTRACT: Represent Org headline

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 level => INT

Level of headline (e.g. 1, 2, 3). Corresponds to the number of bullet stars.

=cut

has level => (is => 'rw');

=head2 title => OBJ

L<Org::Element::Text> representing the headline title

=cut

has title => (is => 'rw');

=head2 todo_priority => STR

String (optional) representing priority.

=cut

has todo_priority => (is => 'rw');

=head2 tags => ARRAY

Arrayref (optional) containing list of defined tags.

=cut

has tags => (is => 'rw');

=head2 is_todo => BOOL

Whether this headline is a TODO item.

=cut

has is_todo => (is => 'rw');

=head2 is_done => BOOL

Whether this TODO item is in a done state (state which requires no more action,
e.g. DONE). Only meaningful if headline is a TODO item.

=cut

has is_done => (is => 'rw');

=head2 todo_state => STR

TODO state.

=cut

has todo_state => (is => 'rw');

=head2 progress => STR

Progress.

=cut

has progress => (is => 'rw');


=head1 METHODS

=for Pod::Coverage element_as_string BUILD

=head2 new(attr => val, ...)

=head2 new(raw => STR, document => OBJ)

Create a new headline item from parsing raw string. (You can also create
directly by filling out priority, title, etc).

=cut

sub BUILD {
    require Org::Parser;
    my ($self, $args) = @_;
    my $raw = $args->{raw};
    my $doc = $self->document;
    if (defined $raw) {
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
                $self->todo_priority($1);
            }
        }

        use Org::Element::Text;
        $self->title(Org::Element::Text->new(raw => $title, document=>$doc));
    }

    if (!ref($self->title)) {
        $self->title(Org::Element::Text->new(
            raw=>$self->title, document=>$doc));
    }
}

sub element_as_string {
    my ($self) = @_;
    return $self->_raw if $self->_raw;
    join("",
         "*" x $self->level,
         " ",
         $self->is_todo ? $self->todo_state." " : "",
         $self->todo_priority ? "[#".$self->todo_priority."] " : "",
         $self->title->as_string,
         $self->tags && @{$self->tags} ?
             "  :".join(":", @{$self->tags}).":" : "",
         "\n");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
