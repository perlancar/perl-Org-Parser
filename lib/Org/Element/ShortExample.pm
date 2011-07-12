package Org::Element::ShortExample;

use 5.010;
use locale;
use Moo;
extends 'Org::Element::Base';

# VERSION

has example => (is => 'rw');
has indent => (is => 'rw');

sub as_string {
    my ($self) = @_;
    join("",
         $self->indent // "",
         ": ",
         $self->example,
         "\n"
     );
}

1;
# ABSTRACT: Represent Org in-buffer settings
__END__

=head1 DESCRIPTION

Short example is one-line literal example which is preceded by colon + space.
Example:

 Here is an example:
   : some example from a text file.
   :   another example.

which is functionally equivalent to:

 Here is an example:
   #+BEGIN_EXAMPLE
   some example from a text file.
   #+END_EXAMPLE
   #+BEGIN_EXAMPLE
     another example.
   #+END_EXAMPLE

Derived from L<Org::Element::Base>.


=head1 ATTRIBUTES

=head2 example => STR

Example content.

=head2 indent => STR

Indentation (whitespaces before C<#+>), or empty string if none.


=head1 METHODS

=for Pod::Coverage as_string BUILD

=cut
