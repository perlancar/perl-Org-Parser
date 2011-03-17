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

=for Pod::Coverage as_string element_as_string BUILD

=head2 new(attr => val, ...)

=head2 new(raw => STR, document => OBJ)

Create a new headline item from parsing raw string. (You can also create
directly by filling out priority, title, etc).

=cut

sub BUILD {
    my ($self, $args) = @_;
    my $raw = $args->{raw};
    if (defined $raw) {
        my $doc = $self->document
            or die "Please specify document when specifying raw";
        state $re = qr/\A\s*:(\w+):\s*\R
                       ((?:.|\R)*?)    # content
                       [ \t]*:END:\z   # closing
                      /xi;
        $raw =~ $re or die "Invalid syntax in drawer: $raw";
        my ($d, $rc) = (uc($1), $2);
        $d ~~ @{ $doc->drawers } or die "Unknown drawer name $d: $raw";
        $self->name($d);
        $self->raw_content($rc);
    }
}

sub element_as_string {
    my ($self) = @_;
    return $self->_raw if $self->_raw;
    join("",
         ":", uc($self->name), ":", "\n",
         $self->children ? $self->children_as_string : $self->raw_content,
         ":END:\n");
}

sub as_string {
    my ($self) = @_;
    $self->element_as_string;
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
