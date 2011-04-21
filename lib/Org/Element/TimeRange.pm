package Org::Element::TimeRange;
# ABSTRACT: Represent Org time range (TS1--TS2)

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 ts1 => TIMESTAMP ELEMENT

=cut

has ts1 => (is => 'rw');

=head2 ts2 => TIMESTAMP ELEMENT

=cut

has ts2 => (is => 'rw');


=head1 METHODS

=for Pod::Coverage as_string

=cut

sub as_string {
    my ($self) = @_;
    return $self->_str if $self->_str;
    join("",
         $self->ts1->as_string,
         "--",
         $self->ts2->as_string
     );
}

1;
__END__

=head1 DESCRIPTION

Derived from L<Org::Element::Base>.

=cut
