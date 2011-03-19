package Org::Element::ScheduleTimestampPair;
# ABSTRACT: Represent Org schedule timestamp pair

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 datetime1

=cut

has datetime1 => (is => 'rw');

=head2 datetime2

=cut

has datetime2 => (is => 'rw');


=head1 METHODS

=for Pod::Coverage as_string

=cut

sub as_string {
    my ($self) = @_;
    join("",
         "<", $self->datetime1->ymd, " ",
         # XXX Thu 11:59
         ">--<", $self->datetime2->ymd, " ",
         # XXX Thu 11:59
         ">");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
