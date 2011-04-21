package Org::Element::ListItem;
# ABSTRACT: Represent Org list item

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 bullet

=cut

has bullet => (is => 'rw');

=head2 check_state

undef, " ", "X" or "-".

=cut

has check_state => (is => 'rw');

=head2 desc_term

Description term (for description list).

=cut

has desc_term => (is => 'rw');


=head1 METHODS

=for Pod::Coverage header_as_string as_string

=cut

sub header_as_string {
    my ($self) = @_;
    join("",
         $self->parent->indent,
         $self->bullet, " ",
         defined($self->check_state) ? "[".$self->check_state."]" : "",
     );
}

sub as_string {
    my ($self) = @_;
    $self->header_as_string . $self->children_as_string;
}

__END__

=head1 DESCRIPTION

Must have L<Org::Element::List> as parent.

Derived from L<Org::Element::Base>.

=cut
