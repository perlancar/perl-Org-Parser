package Org::Element::Base;
# ABSTRACT: Base class for element of Org document

use 5.010;
use Log::Any '$log';
use Moo;
use Scalar::Util qw(refaddr);

=head1 ATTRIBUTES

=head2 document => DOCUMENT

Link to document object. Elements need this e.g. to access file-wide settings,
properties, etc.

=cut

has document => (is => 'rw');

=head2 parent => undef | ELEMENT

Link to parent element.

=cut

has parent => (is => 'rw');

=head2 children => undef | ARRAY_OF_ELEMENTS

=cut

has children => (is => 'rw');

# store the raw string (to preserve original formatting), not all elements use
# this, usually only more complex elements
has _str => (is => 'rw');
has _str_include_children => (is => 'rw');


=head1 METHODS

=head2 $el->children_as_string() => STR

Return a concatenation of children's as_string(), or "" if there are no
children.

=cut

sub children_as_string {
    my ($self) = @_;
    return "" unless $self->children;
    join "", map {$_->as_string} @{$self->children};
}

=head2 $el->as_string() => STR

Return the string representation of element. The default implementation will
just use _str (if defined) concatenated with children_as_string().

=cut

sub as_string {
    my ($self) = @_;

    if (defined $self->_str) {
        return $self->_str .
            ($self->_str_include_children ? "" : $self->children_as_string);
    } else {
        return "" . $self->children_as_string;
    }
}

=head2 $el->seniority => INT

Find out the ranking of brothers/sisters of all sibling. If we are the first
child of parent, return 0. If we are the second child, return 1, and so on.

=cut

sub seniority {
    my ($self) = @_;
    my $c;
    return -4 unless $self->parent && ($c = $self->parent->children);
    my $addr = refaddr($self);
    for (my $i=0; $i < @$c; $i++) {
        return $i if refaddr($c->[$i]) == $addr;
    }
    return undef;
}

=head2 $el->prev_sibling() => ELEMENT | undef

=cut

sub prev_sibling {
    my ($self) = @_;

    my $sen = $self->seniority;
    return undef unless defined($sen) && $sen > 0;
    my $c = $self->parent->children;
    $c->[$sen-1];
}

=head2 $el->next_sibling() => ELEMENT | undef

=cut

sub next_sibling {
    my ($self) = @_;

    my $sen = $self->seniority;
    return undef unless defined($sen);
    my $c = $self->parent->children;
    return undef unless $sen < @$c-1;
    $c->[$sen+1];
}

=head2 $el->get_property($name, $search_parent) => VALUE

Search for property named $name in the nearest properties drawer. If
$search_parent is set to true (default is false), will also search in
upper-level properties (useful for searching for inherited property, like
foo_ALL). Return undef if property cannot be found in all drawers.

Regardless of $search_parent setting, file-wide properties will be consulted if
property is not found in nearest properties drawer.

=cut

sub get_property {
    my ($self, $name, $search_parent) = @_;
    my $p = $self->parent;
    my $s = $p->children if $p;

    if ($s) {
        for my $d (@$s) {
            return unless $d->isa('Org::Element::Drawer')
                && $d->name eq 'PROPERTIES' && $d->properties;
            return $d->properties->{$name} if defined $d->properties->{$name};
        }
    }

    if ($p && $search_parent) {
        my $res = $p->get_property($name, 1);
        return $res if defined $res;
    }

    $log->tracef("Getting property from document's .properties");
    $self->document->properties->{$name};
}

1;
