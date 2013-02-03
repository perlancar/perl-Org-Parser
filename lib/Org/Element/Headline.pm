package Org::Element::Headline;

use 5.010;
use locale;
use Log::Any '$log';
use Moo;
extends 'Org::Element';

# VERSION

has level => (is => 'rw');
has title => (is => 'rw');
has todo_priority => (is => 'rw');
has tags => (is => 'rw');
has is_todo => (is => 'rw');
has is_done => (is => 'rw');
has todo_state => (is => 'rw');
has progress => (is => 'rw');

sub extra_walkables {
    my $self = shift;
    grep {defined} ($self->title);
}

sub header_as_string {
    my ($self) = @_;
    return $self->_str if defined $self->_str;
    join("",
         "*" x $self->level,
         " ",
         $self->is_todo ? $self->todo_state." " : "",
         $self->todo_priority ? "[#".$self->todo_priority."] " : "",
         $self->title->as_string,
         $self->tags && @{$self->tags} ?
             "  :".join(":", @{$self->tags}).":" : "",
         "\n");
}

sub as_string {
    my ($self) = @_;
    $self->header_as_string . $self->children_as_string;
}

sub get_tags {
    my ($self, $name, $search_parent) = @_;
    my @res = @{ $self->tags // [] };
    $self->walk_parents(
        sub {
            my ($el, $parent) = @_;
            return 1 unless $parent->isa('Org::Element::Headline');
            if ($parent->tags) {
                for (@{ $parent->tags }) {
                    push @res, $_ unless $_ ~~ @res;
                }
            }
            1;
        });
    for (@{ $self->document->tags }) {
        push @res, $_ unless $_ ~~ @res;
    }
    @res;
}

sub get_active_timestamp {
    my ($self) = @_;

    for my $s ($self->title, $self) {
        my $ats;
        $s->walk(
            sub {
                my ($el) = @_;
                return if $ats;
                $ats = $el if $el->isa('Org::Element::Timestamp') &&
                    $el->is_active;
            }
        );
        return $ats if $ats;
    }
    return;
}

sub is_leaf {
    my ($self) = @_;

    return 1 unless $self->children;

    my $res;
    for my $child (@{ $self->children }) {
        $child->walk(
            sub {
                return if defined($res);
                my ($el) = @_;
                if ($el->isa('Org::Element::Headline')) {
                    $res = 0;
                    goto EXIT_WALK;
                }
            }
        );
    }
  EXIT_WALK:
    $res //= 1;
    $res;
}

sub promote_node {
    my ($self, $num_levels) = @_;
    $num_levels //= 1;
    return if $num_levels == 0;
    die "Please specify a positive number of levels" if $num_levels < 0;

    for my $i (1..$num_levels) {

        my $l = $self->level;
        last if $l <= 1;
        $l--;
        $self->level($l);

        $self->_str(undef);

        my $parent = $self->parent;
        my $siblings = $parent->children;
        my $pos = $self->seniority;

        # our children stay as children

        # our right sibling headline(s) become children
        while (1) {
            my $s = $siblings->[$pos+1];
            last unless $s && $s->isa('Org::Element::Headline')
                && $s->level > $l;
            $self->children([]) unless defined $self->children;
            push @{$self->children}, $s;
            splice @$siblings, $pos+1, 1;
            $s->parent($self);
        }

        # our parent headline can become sibling if level is the same
        if ($parent->isa('Org::Element::Headline') && $parent->level == $l) {
            splice @$siblings, $pos, 1;
            my $gparent = $parent->parent;
            splice @{$gparent->children}, $parent->seniority+1, 0, $self;
            $self->parent($gparent);
        }

    }
}

sub demote_node {
    my ($self, $num_levels) = @_;
    $num_levels //= 1;
    return if $num_levels == 0;
    die "Please specify a positive number of levels" if $num_levels < 0;

    for my $i (1..$num_levels) {

        my $l = $self->level;
        $l++;
        $self->level($l);

        $self->_str(undef);

        # prev sibling can become parent
        my $ps = $self->prev_sibling;
        if ($ps && $ps->isa('Org::Element::Headline') && $ps->level < $l) {
            splice @{$self->parent->children}, $self->seniority, 1;
            $ps->children([]) if !defined($ps->children);
            push @{$ps->children}, $self;
            $self->parent($ps);
        }

    }
}

sub promote_branch {
    my ($self, $num_levels) = @_;
    $num_levels //= 1;
    return if $num_levels == 0;
    die "Please specify a positive number of levels" if $num_levels < 0;

    for my $i (1..$num_levels) {
        last if $self->level <= 1;
        $_->promote_node() for $self->find('Headline');
    }
}

sub demote_branch {
    my ($self, $num_levels) = @_;
    $num_levels //= 1;
    return if $num_levels == 0;
    die "Please specify a positive number of levels" if $num_levels < 0;

    for my $i (1..$num_levels) {
        $_->demote_node() for $self->find('Headline');
    }
}

sub properties_drawer {
	my $self = shift;

	for my $d (@{$self->children||[]}) {
        $log->tracef("seeking PROPERTIES drawer in child: %s (%s)", $d->as_string, ref($d));
		next unless ($d->isa('Org::Element::Drawer')
					 && $d->name eq 'PROPERTIES'
					 && $d->properties);
		return $d->properties;
	}
}

sub get_property {
    my ($self, $name, $search_parent) = @_;
    #$log->tracef("-> get_property(%s, search_par=%s)", $name, $search_parent);
    my $p = $self->parent;

	my $pd = $self->properties_drawer;
	return $pd->{$name} if ($pd and defined $pd->{$name});

    if ($p && $search_parent) {
        next unless $p->isa('Org::Element::Headline');
        my $res = $p->get_property($name, 1);
        return $res if defined $res;
    }

    $log->tracef("Getting property from document's .properties");
    $self->document->properties->{$name};
}

1;
# ABSTRACT: Represent Org headline
__END__

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 level => INT

Level of headline (e.g. 1, 2, 3). Corresponds to the number of bullet stars.

=head2 title => OBJ

L<Org::Element::Text> representing the headline title

=head2 todo_priority => STR

String (optional) representing priority.

=head2 tags => ARRAY

Arrayref (optional) containing list of defined tags.

=head2 is_todo => BOOL

Whether this headline is a TODO item.

=head2 is_done => BOOL

Whether this TODO item is in a done state (state which requires no more action,
e.g. DONE). Only meaningful if headline is a TODO item.

=head2 todo_state => STR

TODO state.

=head2 progress => STR

Progress.

=head1 METHODS

=for Pod::Coverage header_as_string as_string

=head2 $el->get_tags() => ARRAY

Get tags for this headline. A headline can define tags or inherit tags from its
parent headline (or from document).

=head2 $el->get_active_timestamp() => ELEMENT

Get the first active timestamp element for this headline, either in the title or
in the child elements.

=head2 $el->is_leaf() => BOOL

Returns true if element doesn't contain subtrees.

=head2 $el->promote_node([$num_levels])

Promote (decrease the level) of this headline node. $level specifies number of
levels, defaults to 1. Won't further promote if already at level 1.
Illustration:

 * h1
 ** h2   <-- promote 1 level
 *** h3
 *** h3b
 ** h4
 * h5

becomes:

 * h1
 * h2
 *** h3
 *** h3b
 ** h4
 * h5

=head2 $el->demote_node([$num_levels])

Does the opposite of promote_node().

=head2 $el->promote_branch([$num_levels])

Like promote_node(), but all children headlines will also be promoted.
Illustration:

 * h1
 ** h2   <-- promote 1 level
 *** h3
 **** grandkid
 *** h3b

 ** h4
 * h5

becomes:

 * h1
 * h2
 ** h3
 *** grandkid
 ** h3b

 ** h4
 * h5

=head2 $el->demote_branch([$num_levels])

Does the opposite of promote_branch().

=head2 $el->get_property($name, $search_parent) => VALUE

Search for property named $name in the properties drawer. If $search_parent is
set to true (default is false), will also search in upper-level properties
(useful for searching for inherited property, like foo_ALL). Return undef if
property cannot be found.

Regardless of $search_parent setting, file-wide properties will be consulted if
property is not found in the headline's properties drawer.

=cut
