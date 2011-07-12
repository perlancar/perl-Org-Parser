package Org::Element::Link;

use 5.010;
use locale;
use Moo;
extends 'Org::Element::Base';

# VERSION

has link => (is => 'rw');
has description => (is => 'rw');
has from_radio_target => (is => 'rw');

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
# ABSTRACT: Represent Org hyperlink
__END__

=head1 DESCRIPTION

Derived from L<Org::Element::Base>.


=head1 ATTRIBUTES

=head2 link => STR

=head2 description => STR

=head2 from_radio_target => BOOL


=head1 METHODS

=for Pod::Coverage as_string

=cut
