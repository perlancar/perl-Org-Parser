package Org::Element::RadioTarget;

# DATE
# VERSION

use 5.010;
use locale;
use Moo;
extends 'Org::Element';
with 'Org::Element::InlineRole';

has target => (is => 'rw');

sub BUILD {
    my ($self, $args) = @_;
    my $pass = $args->{pass} // 1;
    my $doc  = $self->document;
    if ($pass == 1) {
        push @{ $doc->radio_targets },
            $self->target;
    }
}

sub as_string {
    my ($self) = @_;
    join("",
         "<<<", $self->target, ">>>");
}

sub as_text {
    goto \&as_string;
}

1;
# ABSTRACT: Represent Org radio target

=for Pod::Coverage ^(BUILD)$

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 target


=head1 METHODS

=head2 as_string => str

From L<Org::Element>.

=head2 as_text => str

From L<Org::Element::InlineRole>.

=cut
