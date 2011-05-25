package Org::Element::Link;
# ABSTRACT: Represent Org hyperlink

use 5.010;
use locale;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 link => STR

=cut

has link => (is => 'rw');

=head2 description => STR

=cut

has description => (is => 'rw');

=head2 from_radio_target => BOOL

=cut

has from_radio_target => (is => 'rw');


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

Derived from L<Org::Element::Base>.

=cut
