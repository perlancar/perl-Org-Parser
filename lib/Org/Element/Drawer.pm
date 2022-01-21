package Org::Element::Drawer;

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
        $self->properties->{$1} = $2;
    }
}

sub as_string {
    my ($self) = @_;
    join("",
         ":", $self->name, ":\n",
         $self->children_as_string,
         ":END:");
}

1;
# ABSTRACT: Represent Org drawer

=for Pod::Coverage BUILD as_string

=head1 DESCRIPTION

Derived from L<Org::Element>.

Example of a drawer in an Org document:

 * A heading
 :SOMEDRAWER:
 some text
 more text ...
 :END:

A special drawer named C<PROPERTIES> is used to store a list of properties:

 * A heading
 :PROPERTIES:
 :Title:   the title
 :Publisher:   the publisher
 :END:


=head1 ATTRIBUTES

=head2 name => STR

Drawer name.

=head2 properties => HASH

Collected properties in the drawer. In the example properties drawer above,
C<properties()> will result in:

 {
   Title => "the title",
   Publisher => "the publisher",
 }


=head1 METHODS

=cut
