package Org::Element::TableRow;

use 5.010;
use locale;
use Moo;
extends 'Org::Element';

# VERSION

sub as_string {
    my ($self) = @_;
    return $self->_str if defined $self->_str;

    join("",
         "|",
         join("|", map {$_->as_string} @{$self->children}),
         "\n");
}

sub as_array {
    my ($self) = @_;

    [map {$_->as_string} @{$self->children}];
}

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
# ABSTRACT: Represent Org table row
__END__

=head1 DESCRIPTION

Derived from L<Org::Element>. Must have L<Org::Element::TableCell>
instances as its children.


=head1 ATTRIBUTES


=head1 METHODS

=for Pod::Coverage as_string

=head2 $table->cells() => ELEMENTS

Return the cells of the row.

=head2 $table->as_array() => ARRAYREF

Return an arrayref containing the cells of the row, each cells already
stringified with as_string().

=cut
