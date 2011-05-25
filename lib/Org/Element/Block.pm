package Org::Element::Block;
# ABSTRACT: Represent Org block

use 5.010;
use locale;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 name => STR

Block name. For example, #+begin_src ... #+end_src is an 'SRC' block.

=cut

has name => (is => 'rw');

=head2 args => ARRAY

=cut

has args => (is => 'rw');

=head2 raw_content => STR

=cut

has raw_content => (is => 'rw');

=head2 begin_indent => STR

Indentation on begin line (before C<#+BEGIN>), or empty string if none.

=cut

has begin_indent => (is => 'rw');

=head2 end_indent => STR

Indentation on end line (before C<#+END>), or empty string if none.

=cut

has end_indent => (is => 'rw');

my @known_blocks = qw(
                         ASCII CENTER COMMENT EXAMPLE HTML
                         LATEX QUOTE SRC VERSE
                 );


=head1 METHODS

=for Pod::Coverage element_as_string BUILD

=cut

sub BUILD {
    my ($self, $args) = @_;
    $self->name(uc $self->name);
    $self->name ~~ @known_blocks or die "Unknown block name: ".$self->name;
}

sub element_as_string {
    my ($self) = @_;
    return $self->_str if defined $self->_str;
    join("",
         $self->begin_indent // "",
         "#+BEGIN_".uc($self->name),
         $self->args && @{$self->args} ?
             " ".Org::Document::__format_args($self->args) : "",
         "\n",
         $self->raw_content,
         $self->end_indent // "",
         "#+END_".uc($self->name)."\n");
}

1;
__END__

=head1 DESCRIPTION

Derived from L<Org::Element::Base>.

=cut
