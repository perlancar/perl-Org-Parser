package Org::Element::Drawer;

use 5.010;
use experimental 'smartmatch';
use locale;
use Moo;
extends 'Org::Element';

# VERSION

has name => (is => 'rw');
has properties => (is => 'rw');

sub BUILD {
    my ($self, $args) = @_;
    my $doc = $self->document;
    my $pass = $args->{pass} // 1;

    if ($pass == 2) {
        die "Unknown drawer name: ".$self->name
            unless $self->name ~~ @{$doc->drawer_names};
    }
}

sub _parse_properties {
    my ($self, $raw_content) = @_;
    $self->properties({}) unless $self->properties;
    while ($raw_content =~ /^[ \t]*:(\w+):[ \t]+
                            ($Org::Document::args_re)[ \t]*(?:\R|\z)/mxg) {
        my $args = Org::Document::__parse_args($2);
        $self->properties->{$1} = @$args == 1 ? $args->[0] : $args;
    }
}

sub as_string {
    my ($self) = @_;
    join("",
         ":", $self->name, ":\n",
         $self->children_as_string,
         ":END:\n");
}

1;
# ABSTRACT: Represent Org drawer
__END__

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 name => STR

Drawer name.

=head2 properties => HASH

Collected properties in the drawer.


=head1 METHODS

=for Pod::Coverage BUILD as_string

=cut
