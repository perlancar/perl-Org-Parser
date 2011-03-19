package Org::Element::Target;
# ABSTRACT: Represent Org target

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 target

=cut

has target => (is => 'rw');


=head1 METHODS

=for Pod::Coverage as_string

=cut

sub as_string {
    my ($self) = @_;
    join("",
         "<<", $self->target, ">>");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
