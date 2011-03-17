package Org::Element::Text;
# ABSTRACT: Represent normal text

use 5.010;
use strict;
use warnings;

use Moo;
extends 'Org::Element::Base';

has _dummy => (is => 'rw'); # workaround for Moo bug [RT#65636]

=for Pod::Coverage BUILD

=cut

sub BUILD {
    my ($self, $args) = @_;
    if (defined $args->{raw}) {
        $self->_raw($args->{raw});
    }
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
