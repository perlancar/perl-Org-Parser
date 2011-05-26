package Org::Element::TableRow;
# ABSTRACT: Represent Org table row

use 5.010;
use locale;
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

=head2 $table->cells() => ELEMENTS

Return the cells of the row.

=cut

sub cells {
    my ($self) = @_;
    return [] unless $self->children;

    my $cells = [];
    for my $el (@{$self->children}) {
        push @$cells, $el if $el->isa('Org::Element::TableCell');
    }
    $cells;
}

1;
__END__

=head1 DESCRIPTION

Derived from L<Org::Element::Base>.

=cut
