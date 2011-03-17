package Org::Element::ScheduleTimestamp;
# ABSTRACT: Represent Org schedule timestamp

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 datetime

=cut

has datetime => (is => 'rw');


=head1 METHODS

=for Pod::Coverage element_as_string BUILD

=head2 new(attr => val, ...)

=head2 new(raw => STR, document => OBJ)

Create a new headline item from parsing raw string. (You can also create
directly by filling out priority, title, etc).

=cut

sub BUILD {
    require Org::Parser;
    my ($self, $args) = @_;
    my $raw = $args->{raw};
    my $doc = $self->document;
    if (defined $raw) {
        state $re = qr/^<(.+)>$/;
        $raw =~ $re or die "Invalid syntax in timestamp: $raw";
        my $ts = Org::Parser::__parse_timestamp($1)
            or die "Can't parse timestamp $1";
        $self->datetime($ts);
    }
}

sub element_as_string {
    my ($self) = @_;
    return $self->_raw if $self->_raw;
    join("",
         "<", $self->datetime->ymd, " ",
         # XXX Thu 11:59
         ">");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
