package Org::Element::Target;

use 5.010;
use locale;
use Moo;
extends 'Org::Element::Base';

# VERSION

has target => (is => 'rw');

sub as_string {
    my ($self) = @_;
    join("",
         "<<", ($self->target // ""), ">>");
}

1;
# ABSTRACT: Represent Org target
__END__

=head1 DESCRIPTION

Derived from L<Org::Element::Base>.


=head1 ATTRIBUTES

=head2 target


=head1 METHODS

=for Pod::Coverage as_string

=cut
