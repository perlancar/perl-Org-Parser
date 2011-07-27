package Org::Element::TimeRange;

use 5.010;
use locale;
use Moo;
extends 'Org::Element';

# VERSION

has ts1 => (is => 'rw');
has ts2 => (is => 'rw');

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
# ABSTRACT: Represent Org time range (TS1--TS2)
__END__

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 ts1 => TIMESTAMP ELEMENT

Starting timestamp.

=head2 ts2 => TIMESTAMP ELEMENT

Ending timestamp.


=head1 METHODS

=for Pod::Coverage as_string

=cut
