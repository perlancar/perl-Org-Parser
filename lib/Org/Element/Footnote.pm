package Org::Element::Footnote;

# DATE
# VERSION

use 5.010;
use locale;
use Log::Any '$log';
use Moo;
extends 'Org::Element';
with 'Org::Element::InlineRole';

has name => (is => 'rw');
has is_ref => (is => 'rw');
has def => (is => 'rw');

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

sub as_text {
    goto \&as_string;
}

1;
# ABSTRACT: Represent Org footnote reference and/or definition

=for Pod::Coverage ^(BUILD)$

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 name => STR|undef

Can be undef, for anonymous footnote (but in case of undef, is_ref must be
true and def must also be set).

=head2 is_ref => BOOL

Set to true to make this a footnote reference.

=head2 def => TEXT ELEMENT

Set to make this a footnote definition.


=head1 METHODS

=head2 as_string => str

From L<Org::Element>.

=head2 as_text => str

From L<Org::Element::InlineRole>.


