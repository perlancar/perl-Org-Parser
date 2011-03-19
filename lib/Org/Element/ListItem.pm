package Org::Element::ListItem;
# ABSTRACT: Represent Org list item

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 indent

=cut

has indent => (is => 'rw');

=head2 bullet

=cut

has bullet => (is => 'rw');

=head2 check_state

undef, " ", "X" or "-".

=cut

has check_state => (is => 'rw');


=head1 METHODS

=for Pod::Coverage header_as_string

=cut

sub header_as_string {
    my ($self) = @_;
    join("",
         $self->indent,
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

Derived from Org::Element::Base.

=cut
