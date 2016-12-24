package Org::Element::InlineRole;

# DATE
# VERSION

use 5.010;
use Moo::Role;

requires 'as_text';

sub is_block { 0 }

sub is_inline { 1 }

sub children_as_text {
    my ($self) = @_;
    return "" unless $self->children;
    join "", map {$_->as_text} @{$self->children};
}

1;
# ABSTRACT: Role for inline elements

=head1 DESCRIPTION

This role is applied to elements that are "inline": elements that can occur
inside text and put as a child of L<Org::Element::Text>.

=head1 REQUIRES

=head2 as_text => str

Get the "rendered plaintext" representation of element. Most elements would
return the same result as C<as_string>, except for elements like
L<Org::Element::Link> which will return link description instead of the link
itself.


=head1 METHODS

=head2 is_block => bool (0)

=head2 is_inline => bool (1)

=head2 children_as_text => str
