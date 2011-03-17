package Org::Element::TableRow;
# ABSTRACT: Represent Org table row

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 DESCRIPTION

Must have L<Org::Element::TableCell> instances as its children.


=head1 ATTRIBUTES


=head1 METHODS

=for Pod::Coverage children_as_string

=cut

sub children_as_string {
    my ($self) = @_;
    my @res;
    push @res, map { ("|", $_->as_string) } @{ $self->children };
    push @res, "\n";
    join "", @res;
}

=cut

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
