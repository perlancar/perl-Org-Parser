package Org::Element::TableRow;
# ABSTRACT: Represent Org table row

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 DESCRIPTION

Must have L<Org::Element::TableCell> instances as its children.


=head1 ATTRIBUTES


=head1 METHODS

=for Pod::Coverage as_string

=cut

sub as_string {
    my ($self) = @_;
    return $self->_str if defined $self->_str;

    join("",
         "|",
         join("|", map {$_->as_string} @{$self->children}),
         "\n");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
