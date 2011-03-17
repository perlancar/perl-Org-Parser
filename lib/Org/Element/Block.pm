package Org::Element::Block;
# ABSTRACT: Represent Org block

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 name => STR

Block name. For example, #+begin_src ... #+end_src is an 'SRC' block.

=cut

has name => (is => 'rw');

=head2 raw_arg => STR

Argument of block. For example:

 #+BEGIN_EXAMPLE -t -w40
 ...
 #+END_EXAMPLE

will have '-t -w40' as the raw_arg value.

=cut

has raw_arg => (is => 'rw');

=head2 raw_content => STR

Content of block. In the previous 'raw_arg' example, 'raw_content' is "...\n".

=cut

has raw_content => (is => 'rw');


=head1 METHODS

=for Pod::Coverage element_as_string BUILD

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
        state $re = qr/\A\#\+(?:BEGIN_(
                               ASCII|CENTER|COMMENT|EXAMPLE|HTML|
                               LATEX|QUOTE|SRC|VERSE
                       ))
                       (?:\s+(\S.*))\R # arg
                       ((?:.|\R)*)     # content
                       \#\+\w+\R?\z    # closing
                      /xi;
        $raw =~ $re or die "Unknown block or invalid syntax: $raw";
        $self->_raw($raw);
        $self->name(uc($1));
        $self->raw_arg($2);
        $self->raw_content($3);
    }
}

sub element_as_string {
    my ($self) = @_;
    return $self->_raw if $self->_raw;
    join("",
         "#+BEGIN_".uc($self->name),
         defined($self->raw_arg) ? " ".$self->raw_arg : "",
         "\n",
         $self->raw_content,
         "#+END_".uc($self->name)."\n");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
