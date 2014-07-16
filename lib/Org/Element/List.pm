package Org::Element::List;

use 5.010;
use locale;
use Moo;
extends 'Org::Element';

# VERSION

has indent => (is => 'rw');
has type => (is => 'rw');
has bullet_style => (is => 'rw');

sub items {
    my $self = shift;
    my @items;
    for (@{ $self->children }) {
        push @items, $_ if $_->isa('Org::Element::ListItem');
    }
    \@items;
}

1;
# ABSTRACT: Represent Org list

=for Pod::Coverage

=head1 DESCRIPTION

Must have L<Org::Element::ListItem> (or another ::List) as children.

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 indent

Indent (e.g. " " x 2).

=head2 type

'U' for unordered list (-, +, * for bullets), 'D' for description list, 'O' for
ordered list (1., 2., 3., and so on).

=head2 bullet_style

E.g. '-', '*', '+'. For ordered list, currently just use '<N>.'


=head1 METHODS

=head2 $list->items() => ARRAY OF OBJECTS

Return the items, which are an arrayref of L<Org::Element::ListItem> objects.

=cut
