package Org::Element::Base;
# ABSTRACT: Base class for element of Org document

use 5.010;
use strict;
use warnings;

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

=head2 $el->as_string() => STR

Return the string representation of element. If there is _raw value defined,
simply return it. Otherwise, will concatenate as_string() from all of its
children. Child classes might want to override for better representation.

=cut

sub as_string {
    my ($self) = @_;
    return $self->_raw if defined $self->_raw;
    return "" unless $self->children;
    join "", map { $_->as_string } @{ $self->children };
}

1;
