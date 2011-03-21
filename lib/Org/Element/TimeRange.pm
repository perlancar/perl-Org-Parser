package Org::Element::TimeRange;
# ABSTRACT: Represent Org time range (TS1--TS2)

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 datetime1 => DATETIME_OBJ

=cut

has datetime1 => (is => 'rw');

=head2 datetime2 => DATETIME_OBJ

=cut

has datetime2 => (is => 'rw');

=head2 is_active => BOOL

=cut

has is_active => (is => 'rw');


=head1 METHODS

=for Pod::Coverage as_string

=cut

sub as_string {
    my ($self) = @_;
    return $self->_str if $self->_str;
    join("",
         $self->is_active ? "<" : "[",
         $self->datetime1->ymd, " ",
         # XXX Thu 11:59
         $self->is_active ? ">--<" : "]--[",
         $self->datetime2->ymd, " ",
         # XXX Thu 11:59
         $self->is_active ? ">" : "]",
     );
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
