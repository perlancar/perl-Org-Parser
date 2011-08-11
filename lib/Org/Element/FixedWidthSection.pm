package Org::Element::FixedWidthSection;

use 5.010;
use locale;
use Moo;
extends 'Org::Element';

# VERSION

sub text {
    my ($self) = @_;
    my $res = $self->_str;
    $res =~ s/^[ \t]*: ?//mg;
    $res;
}

1;
# ABSTRACT: Represent Org fixed-width section
__END__

=head1 SYNOPSIS

 use Org::Element::FixedWidthSection;
 my $el = Org::Element::FixedWidthSection->new(_str => ": line1\n: line2\n");

=head1 DESCRIPTION

Fixed width section is a block of text where each line is prefixed by colon +
space (or just a colon + space or a colon). Example:

 Here is an example:
   : some example from a text file.
   :   second line.
   :
   : fourth line, after the empty above.

which is functionally equivalent to:

 Here is an example:
   #+BEGIN_EXAMPLE
   some example from a text file.
     another example.

   fourth line, after the empty above.
   #+END_EXAMPLE

Derived from L<Org::Element>.


=head1 ATTRIBUTES


=head1 METHODS

=head2 $el->text => STR

The text (without colon prefix).


=for Pod::Coverage as_string BUILD

=cut
