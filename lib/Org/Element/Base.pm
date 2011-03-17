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

=head2 children => undef | ARRAY[ELEMENTS]

=cut

has children => (is => 'rw');

# normally only leaf nodes will store _raw values, to avoid duplication
has _raw => (is => 'rw');


=head1 METHODS

=head2 $el->element_as_string() => STR

Return the string representation of element. The default implementation will
just try to return _raw or empty string. Subclasses might want to override for
more appropriate representation.

=cut

sub element_as_string {
    my ($self) = @_;
    return $self->_raw if defined $self->_raw;
    "";
}

=head2 $el->children_as_string() => STR

Return the string representation of children elements. The default
implementation will just try to concatenate as_string() for each child.

=cut

sub children_as_string {
    my ($self) = @_;
    return "" unless $self->children;
    join "", map { $_->as_string } @{ $self->children };
}

=head2 $el->as_string() => STR

Return the string representation of element. The default implementation will
just concatenate element_as_string() and children_as_string(). Subclasses might
want to override for more appropriate representation.

=cut

sub as_string {
    my ($self) = @_;
    ($self->element_as_string // "") . ($self->children_as_string // "");
}

1;
