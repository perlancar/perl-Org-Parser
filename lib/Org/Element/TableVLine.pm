package Org::Element::TableVLine;
# ABSTRACT: Represent Org table vertical line

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES


=head1 METHODS

=for Pod::Coverage as_string

=cut

sub as_string {
    my ($self) = @_;
    return $self->_raw if $self->_raw;
    "|---\n";
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
