package Org::Element::Block;

use 5.010;
use locale;
use Moo;
use experimental 'smartmatch';
extends 'Org::Element';
with 'Org::Element::Role';
with 'Org::Element::BlockRole';

# AUTHORITY
# DATE
# DIST
# VERSION

has name => (is => 'rw');
has args => (is => 'rw');
has raw_content => (is => 'rw');
has begin_indent => (is => 'rw');
has end_indent => (is => 'rw');

my @known_blocks = qw(
                         ASCII CENTER COMMENT EXAMPLE HTML
                         LATEX QUOTE SRC VERSE
                 );

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
# ABSTRACT: Represent Org block

=for Pod::Coverage element_as_string BUILD

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 name => STR

Block name. For example, #+begin_src ... #+end_src is an 'SRC' block.

=head2 args => ARRAY

=head2 raw_content => STR

=head2 begin_indent => STR

Indentation on begin line (before C<#+BEGIN>), or empty string if none.

=head2 end_indent => STR

Indentation on end line (before C<#+END>), or empty string if none.


=head1 METHODS

=cut
