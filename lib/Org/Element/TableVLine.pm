package Org::Element::TableVLine;

use 5.010;
use locale;
use Moo;
extends 'Org::Element';

# VERSION

sub as_string {
    my ($self) = @_;
    return $self->_str if $self->_str;
    "|---\n";
}

1;
#ABSTRACT: Represent Org table vertical line

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES


=head1 METHODS

=for Pod::Coverage as_string

=cut
