package Org::Element::Link;
# ABSTRACT: Represent Org hyperlink

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 link

=cut

has link => (is => 'rw');

=head2 description

=cut

has description => (is => 'rw');


=head1 METHODS

=for Pod::Coverage as_string

=cut

sub as_string {
    my ($self) = @_;
    return $self->_str if defined $self->_str;
    join("",
         "[",
         "[", $self->link, "]",
         (defined($self->description) && length($self->description) ?
              ("[", $self->description, "]") : ()),
         "]");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
