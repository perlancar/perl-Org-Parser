package Org::Element::Headline;

use 5.010;
use locale;
use Moo;
extends 'Org::Element::Base';

# VERSION

has level => (is => 'rw');
has title => (is => 'rw');
has todo_priority => (is => 'rw');
has tags => (is => 'rw');
has is_todo => (is => 'rw');
has is_done => (is => 'rw');
has todo_state => (is => 'rw');
has progress => (is => 'rw');

sub header_as_string {
    my ($self) = @_;
    return $self->_str if defined $self->_str;
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

sub as_string {
    my ($self) = @_;
    $self->header_as_string . $self->children_as_string;
}

sub get_tags {
    my ($self, $name, $search_parent) = @_;
    my @res = @{ $self->tags // [] };
    $self->walk_parents(
        sub {
            my ($el, $parent) = @_;
            return 1 unless $parent->isa('Org::Element::Headline');
            if ($parent->tags) {
                for (@{ $parent->tags }) {
                    push @res, $_ unless $_ ~~ @res;
                }
            }
            1;
        });
    for (@{ $self->document->tags }) {
        push @res, $_ unless $_ ~~ @res;
    }
    @res;
}

sub get_active_timestamp {
    my ($self) = @_;

    for my $s ($self->title, $self) {
        my $ats;
        $s->walk(
            sub {
                my ($el) = @_;
                return if $ats;
                $ats = $el if $el->isa('Org::Element::Timestamp') &&
                    $el->is_active;
            }
        );
        return $ats if $ats;
    }
    return;
}

sub is_leaf {
    my ($self) = @_;

    return 1 unless $self->children;

    my $res;
    for my $child (@{ $self->children }) {
        $child->walk(
            sub {
                return if defined($res);
                my ($el) = @_;
                if ($el->isa('Org::Element::Headline')) {
                    $res = 0;
                    goto EXIT_WALK;
                }
            }
        );
    }
  EXIT_WALK:
    $res //= 1;
    $res;
}

1;
# ABSTRACT: Represent Org headline
__END__

=head1 DESCRIPTION

Derived from L<Org::Element::Base>.


=head1 ATTRIBUTES

=head2 level => INT

Level of headline (e.g. 1, 2, 3). Corresponds to the number of bullet stars.

=head2 title => OBJ

L<Org::Element::Text> representing the headline title

=head2 todo_priority => STR

String (optional) representing priority.

=head2 tags => ARRAY

Arrayref (optional) containing list of defined tags.

=head2 is_todo => BOOL

Whether this headline is a TODO item.

=head2 is_done => BOOL

Whether this TODO item is in a done state (state which requires no more action,
e.g. DONE). Only meaningful if headline is a TODO item.

=head2 todo_state => STR

TODO state.

=head2 progress => STR

Progress.

=head1 METHODS

=for Pod::Coverage header_as_string as_string

=head2 $el->get_tags() => ARRAY

Get tags for this headline. A headline can define tags or inherit tags from its
parent headline (or from document).

=head2 $el->get_active_timestamp() => ELEMENT

Get the first active timestamp element for this headline, either in the title or
in the child elements.

=head2 $el->is_leaf() => BOOL

Returns true if element doesn't contain subtrees.

=cut
