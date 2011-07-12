package Org::Element::Text;

use 5.010;
use locale;
use Moo;
extends 'Org::Element::Base';

# VERSION

has text => (is => 'rw');
has style => (is => 'rw');

our %mu2style = (''=>'', '*'=>'B', '_'=>'U', '/'=>'I',
                 '+'=>'S', '='=>'C', '~'=>'V');
our %style2mu = reverse(%mu2style);

sub as_string {
    my ($self) = @_;
    my $muchar = $style2mu{$self->style // ''} // '';

    join("",
         $muchar,
         $self->text // '', $self->children_as_string,
         $muchar);
}

1;
# ABSTRACT: Represent text
__END__

=head1 DESCRIPTION

Derived from L<Org::Element::Base>.


=head1 ATTRIBUTES

=head2 text

=head2 style

''=normal, I=italic, B=bold, U=underline, S=strikethrough, V=verbatim,
C=code


=head1 METHODS

=for Pod::Coverage as_string

=cut

=cut
