package Org::Element::Timestamp;
# ABSTRACT: Represent Org timestamp

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 datetime

=cut

has datetime => (is => 'rw');


=head1 METHODS

=for Pod::Coverage as_string

=cut

sub as_string {
    my ($self) = @_;
    return $self->_str if $self->_str;
    join("",
         "[", $self->datetime->ymd, " ",
         # XXX Thu 11:59
         "]");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
