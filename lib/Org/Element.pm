package Org::Element;

use 5.010;
use locale;
use Log::ger;
use Moo;
use Scalar::Util qw(refaddr);

# AUTHORITY
# DATE
# DIST
# VERSION

has document => (is => 'rw');
has parent => (is => 'rw');
has children => (is => 'rw');

# store the raw string (to preserve original formatting), not all elements use
# this, usually only more complex elements
has _str => (is => 'rw');
has _str_include_children => (is => 'rw');

sub die {
    my ($self, $msg) = @_;
    die $msg .
        " (element: ".ref($self).
        ", document: ".($self->document && $self->document->_srclabel ? $self->document->_srclabel : "-").")";
}

sub children_as_string {
    my ($self) = @_;
    return "" unless $self->children;
    join "", map {$_->as_string} @{$self->children};
}

sub as_string {
    my ($self) = @_;

    if (defined $self->_str) {
        return $self->_str .
            ($self->_str_include_children ? "" : $self->children_as_string);
    } else {
        return "" . $self->children_as_string;
    }
}

sub seniority {
    my ($self) = @_;
    my $c;
    return -4 unless $self->parent && ($c = $self->parent->children);
    my $addr = refaddr($self);
    for (my $i=0; $i < @$c; $i++) {
        return $i if refaddr($c->[$i]) == $addr;
    }
    return undef; ## no critic: Subroutines::ProhibitExplicitReturnUndef
}

sub prev_sibling {
    my ($self) = @_;

    my $sen = $self->seniority;
    return undef unless defined($sen) && $sen > 0; ## no critic: Subroutines::ProhibitExplicitReturnUndef
    my $c = $self->parent->children;
    $c->[$sen-1];
}

sub next_sibling {
    my ($self) = @_;

    my $sen = $self->seniority;
    return undef unless defined($sen); ## no critic: Subroutines::ProhibitExplicitReturnUndef
    my $c = $self->parent->children;
    return undef unless $sen < @$c-1; ## no critic: Subroutines::ProhibitExplicitReturnUndef
    $c->[$sen+1];
}

sub extra_walkables { return () }

sub walk {
    my ($self, $code, $_level) = @_;
    $_level //= 0;
    $code->($self, $_level);
    if ($self->children) {
        # we need to copy children first to a temporary array so that in the
        # event when during walk a child is removed, all the children are still
        # walked into.
        my @children = @{ $self->children };
        for (@children) {
            $_->walk($code, $_level+1);
        }
    }
    $_->walk($code, $_level+1) for $self->extra_walkables;
}

sub find {
    my ($self, $criteria) = @_;
    return unless $self->children;
    my @res;
    $self->walk(
        sub {
            my $el = shift;
            if (ref($criteria) eq 'CODE') {
                push @res, $el if $criteria->($el);
            } elsif ($criteria =~ /^\w+$/) {
                push @res, $el if $el->isa("Org::Element::$criteria");
            } else {
                push @res, $el if $el->isa($criteria);
            }
        });
    @res;
}

sub walk_parents {
    my ($self, $code) = @_;
    my $parent = $self->parent;
    while ($parent) {
        return $parent unless $code->($self, $parent);
        $parent = $parent->parent;
    }
    return;
}

sub headline {
    my ($self) = @_;
    my $h;
    $self->walk_parents(
        sub {
            my ($el, $p) = @_;
            if ($p->isa('Org::Element::Headline')) {
                $h = $p;
                return;
            }
            1;
        });
    $h;
}

sub headlines {
    my ($self) = @_;
    my @res;
    $self->walk_parents(
        sub {
            my ($el, $p) = @_;
            if ($p->isa('Org::Element::Headline')) {
                push @res, $p;
            }
            1;
        });
    @res;
}

sub settings {
    my ($self, $criteria) = @_;

    my @settings = grep { $_->isa("Org::Element::Setting") }
        @{ $self->children };
    if ($criteria) {
        if (ref $criteria eq 'CODE') {
            @settings = grep { $criteria->($_) } @settings;
        } else {
            @settings = grep { $_->name eq $criteria } @settings;
        }
    }
    @settings;
}

sub field_name {
    my ($self) = @_;

    my $prev = $self->prev_sibling;
    if ($prev && $prev->isa('Org::Element::Text')) {
        my $text = $prev->as_string;
        if ($text =~ /(?:\A|\R)\s*(.+?)\s*:\s*\z/) {
            return $1;
        }
    }
    my $parent = $self->parent;
    if ($parent && $parent->isa('Org::Element::ListItem')) {
        my $list = $parent->parent;
        if ($list->type eq 'D') {
            return $parent->desc_term->as_string;
        }
    }
    # TODO
    #if ($parent && $parent->isa('Org::Element::Drawer') &&
    #        $parent->name eq 'PROPERTIES') {
    #}
    return;
}

sub remove {
    my ($self) = @_;
    my $parent = $self->parent;
    return unless $parent;
    splice @{$parent->children}, $self->seniority, 1;
}

1;
# ABSTRACT: Base class for Org document elements

=head1 SYNOPSIS

 # Don't use directly, use the other Org::Element::* classes.


=head1 DESCRIPTION

This is the base class for all the other Org element classes.


=head1 ATTRIBUTES

=head2 document => DOCUMENT

Link to document object. Elements need this to access file-wide settings,
properties, etc.

=head2 parent => undef | ELEMENT

Link to parent element. Undef if this element is the root element.

=head2 children => undef | ARRAY_OF_ELEMENTS


=head1 METHODS

=head2 $el->children_as_string() => STR

Return a concatenation of children's as_string(), or "" if there are no
children.

=head2 $el->as_string() => STR

Return the string representation of element. The default implementation will
just use _str (if defined) concatenated with children_as_string().

=head2 $el->seniority => INT

Find out the ranking of brothers/sisters of all sibling. If we are the first
child of parent, return 0. If we are the second child, return 1, and so on.

=head2 $el->prev_sibling() => ELEMENT | undef

=head2 $el->next_sibling() => ELEMENT | undef

=head2 $el->extra_walkables => LIST

Return extra walkable elements. The default is to return an empty list, but some
elements can have this, for L<Org::Element::Headline>'s title is also a walkable
element.

=head2 $el->walk(CODEREF)

Call CODEREF for node and all descendent nodes (and extra walkables),
depth-first. Code will be given the element object as argument.

=head2 $el->find(CRITERIA) => ELEMENTS

Find subelements. CRITERIA can be a word (e.g. 'Headline' meaning of class
'Org::Element::Headline') or a class name ('Org::Element::ListItem') or a
coderef (which will be given the element to test). Will return matched elements.

=head2 $el->walk_parents(CODE)

Run CODEREF for parent, and its parent, and so on until the root element (the
document), or until CODEREF returns a false value. CODEREF will be supplied
($el, $parent). Will return the last parent walked.

=head2 $el->headline() => ELEMENT

Get current headline. Return undef if element is not under any headline.

=head2 $el->headlines() => ELEMENTS

Get current headline (in the first element of the result list), its parent, its
parent's parent, and so on until the topmost headline. Return empty list if
element is not under any headline.

=head2 $el->settings(CRITERIA) => ELEMENTS

Get L<Org::Element::Setting> nodes directly under the element. Equivalent to:

 my @settings = grep { $_->isa("Org::Element::Setting") } @{ $el->children };

If CRITERIA is specified, will filter based on some criteria. CRITERIA can be a
coderef, or a string to filter by setting's name, example:

 my ($doc_title) = $doc->settings('TITLE');

Take note of the list operator on the left because C<settings()> return a list.

=head2 $el->field_name() => STR

Try to extract "field name", being defined as either some text on the left side:

 DEADLINE: <2011-06-09 >

or a description term in a description list:

 - wedding anniversary :: <2011-06-10 >

=head2 $el->remove()

Remove element from the tree. Basically just remove the element from its parent.

=cut
