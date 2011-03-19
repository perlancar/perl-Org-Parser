package Org::Element::Drawer;
# ABSTRACT: Represent Org drawer

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 name => STR

Drawer name.

=cut

has name => (is => 'rw');

=head2 raw_content => STR

=cut

has raw_content => (is => 'rw');


=head1 METHODS

=for Pod::Coverage as_string BUILD

=cut

sub BUILD {
    my ($self, $args) = @_;
    if (!defined($self->_str_include_children)) {
        $self->_str_include_children(1);
    }
}

sub as_string {
    my ($self) = @_;
    return $self->_str if defined $self->_str;
    join("",
         ":", uc($self->name), ":", "\n",
         $self->children ? $self->children_as_string : $self->raw_content,
         ":END:\n");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
