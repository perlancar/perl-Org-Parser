package Org::Element::Footnote;
# ABSTRACT: Represent Org footnote reference and/or definition

use 5.010;
use Log::Any '$log';
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 name => STR|undef

Can be undef, for anonymous footnote (but in case of undef, is_ref must be
true and def must also be set).

=cut

has name => (is => 'rw');

=head2 is_ref => BOOL

Set to true to make this a footnote reference.

=cut

has is_ref => (is => 'rw');

=head2 def => TEXT ELEMENT

Set to make this a footnote definition.

=cut

has def => (is => 'rw');


=head1 METHODS

=for Pod::Coverage as_string BUILD

=cut

sub BUILD {
    my ($self, $args) = @_;
    $log->tracef("name = %s", $self->name);
}

sub as_string {
    my ($self) = @_;

    join("",
         "[fn:", ($self->name // ""),
         defined($self->def) ? ":".$self->def->as_string : "",
         "]");
}

1;
__END__

=head1 DESCRIPTION

Derived from L<Org::Element::Base>.

=cut
