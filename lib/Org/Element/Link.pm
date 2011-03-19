package Org::Element::Link;
# ABSTRACT: Represent Org hyperlink

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 link

=cut

has link => (is => 'rw');

=head2 description

=cut

has description => (is => 'rw');


=head1 METHODS

=for Pod::Coverage element_as_string BUILD

=cut

sub BUILD {
    require Org::Parser;
    my ($self, $args) = @_;
    my $raw = $args->{raw};
    my $doc = $self->document;
    if (defined $raw) {
        state $re = qr/^\[\[([^\]]+)\](?:\[([^\]]+)\])?\]$/;
        $raw =~ $re or die "Invalid syntax in link: $raw";
        $self->link($1);
        $self->description($2);
    }
}

sub element_as_string {
    my ($self) = @_;
    return $self->_raw if $self->_raw;
    join("",
         "[",
         "[", $self->link, "]",
         (defined($self->description) && length($self->description) ?
              ("[", $self->description, "]") : ()),
         "]");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
