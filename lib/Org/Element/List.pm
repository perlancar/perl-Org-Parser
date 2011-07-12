package Org::Element::List;

use 5.010;
use locale;
use Moo;
extends 'Org::Element::Base';

# VERSION

has indent => (is => 'rw');
has type => (is => 'rw');
has bullet_style => (is => 'rw');

1;
# ABSTRACT: Represent Org list
__END__

=head1 DESCRIPTION

Must have L<Org::Element::ListItem> (or another ::List) as children.

Derived from L<Org::Element::Base>.


=head1 ATTRIBUTES

=head2 indent

Indent (e.g. " " x 2).

=head2 type

'U' for unordered list (-, +, * for bullets), 'D' for description list, 'O' for
ordered list (1., 2., 3., and so on).

=head2 bullet_style

E.g. '-', '*', '+'. For ordered list, currently just use '<N>.'


=head1 METHODS

=for Pod::Coverage

=cut
