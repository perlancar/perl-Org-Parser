package Org::Element::Text;
# ABSTRACT: Represent normal text

use 5.010;
use strict;
use warnings;

use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 text_style

undef/''=normal, I=italic, B=bold, U=underline, S=strikethrough, V=verbatim

=cut

has text_style => (is => 'rw');


=head1 METHODS

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
