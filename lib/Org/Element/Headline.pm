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

=for Pod::Coverage header_as_string as_string

=cut

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

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
