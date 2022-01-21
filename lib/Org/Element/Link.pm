package Org::Element::Link;

use 5.010;
use locale;
use Moo;
extends 'Org::Element';
with 'Org::Element::Role';
with 'Org::Element::InlineRole';

# AUTHORITY
# DATE
# DIST
# VERSION

has link => (is => 'rw');
has description => (is => 'rw');
has from_radio_target => (is => 'rw');

sub as_string {
    my ($self) = @_;
    return $self->_str if defined $self->_str;
    join("",
         "[",
         "[", $self->link, "]",
         (defined($self->description) && length($self->description) ?
              ("[", $self->description->as_string, "]") : ()),
         "]");
}

sub as_text {
    my $self = shift;
    my $desc = $self->description;
    defined($desc) ? $desc->as_text : $self->link;
}

1;
# ABSTRACT: Represent Org hyperlink

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 link => STR

=head2 description => OBJ

=head2 from_radio_target => BOOL


=head1 METHODS

=head1 as_string => str

From L<Org::Element>.

=head2 as_text => str

From L<Org::Element::InlineRole>.
