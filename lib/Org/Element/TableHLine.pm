package Org::Element::TableHLine;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010;
use locale;
use Moo;
extends 'Org::Element';

sub as_string {
    my ($self) = @_;
    return $self->_str if $self->_str;
    "|---\n";
}

1;
#ABSTRACT: Represent Org table horizontal line

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES


=head1 METHODS

=for Pod::Coverage as_string

=cut
