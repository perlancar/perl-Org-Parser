package Org::Element::Text;

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

sub as_text {
    my $self = shift;
    my $muchar = $style2mu{$self->style // ''} // '';

    join("",
         $muchar,
         $self->text // '', $self->children_as_text,
         $muchar);
}

1;
# ABSTRACT: Represent text

=for Pod::Coverage as_string

=head1 DESCRIPTION

Derived from L<Org::Element>.

Org::Element::Text is an object that represents a piece of text. It has C<text>
and C<style> attributes. Simple text like C<Jakarta> or C<*Jakarta!*> will be
represented, respectively, as C<(text=Jakarta, style='')> and C<text=Jakarta!,
style=B> (for bold).

This object can also hold other inline (non-block) elements, e.g. links, radio
targets, timestamps, time ranges. They are all put in the C<children> attribute.


=head1 ATTRIBUTES

=head2 text => str

Plain text for this object I<only>. Note that if you want to get a plain text
representation for the whole text (including child elements), you'd want the
C<as_text> method.

=head2 style => str

''=normal, I=italic, B=bold, U=underline, S=strikethrough, V=verbatim,
C=code


=head1 METHODS

=head2 as_text => str

From L<Org::Element::InlineRole>.

=head2 as_string => str

From L<Org::Element>.
