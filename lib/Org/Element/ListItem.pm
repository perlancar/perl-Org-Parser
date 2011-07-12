package Org::Element::ListItem;

use 5.010;
use locale;
use Moo;
extends 'Org::Element::Base';

# VERSION

has bullet => (is => 'rw');
has check_state => (is => 'rw');
has desc_term => (is => 'rw');

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
# ABSTRACT: Represent Org list item

=head1 DESCRIPTION

Must have L<Org::Element::List> as parent.

Derived from L<Org::Element::Base>.


=head1 ATTRIBUTES

=head2 bullet

=head2 check_state

undef, " ", "X" or "-".

=head2 desc_term

Description term (for description list).


=head1 METHODS

=for Pod::Coverage header_as_string as_string

=cut
