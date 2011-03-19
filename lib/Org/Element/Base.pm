package Org::Element::Base;
# ABSTRACT: Base class for element of Org document

use 5.010;
use Moo;

=head1 ATTRIBUTES

=head2 document => DOCUMENT

Link to document object. Elements need this e.g. to access file-wide settings,
properties, etc.

=cut

has document => (is => 'rw');

=head2 parent => undef | ELEMENT

Link to parent element.

=cut

has parent => (is => 'rw');

=head2 children => undef | ARRAY_OF_ELEMENTS

=cut

has children => (is => 'rw');

# store the raw string (to preserve original formatting), not all elements use
# this, usually only more complex elements
has _str => (is => 'rw');
has _str_include_children => (is => 'rw');


=head1 METHODS

=head2 $el->children_as_string() => STR

Return a concatenation of children's as_string(), or "" if there are no
children.

=cut

sub children_as_string {
    my ($self) = @_;
    return "" unless $self->children;
    join "", map {$_->as_string} @{$self->children};
}

=head2 $el->as_string() => STR

Return the string representation of element. The default implementation will
just use _str (if defined) concatenated with children_as_string().

=cut

sub as_string {
    my ($self) = @_;

    if (defined $self->_str) {
        return $self->_str .
            ($self->_str_include_children ? "" : $self->children_as_string);
    } else {
        return "" . $self->children_as_string;
    }
}

1;
