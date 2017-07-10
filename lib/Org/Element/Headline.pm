package Org::Element::Headline;

# DATE
# VERSION

use 5.010;
use locale;
use Log::ger;
use Moo;
use experimental 'smartmatch';
extends 'Org::Element';
with 'Org::Element::Role';
with 'Org::Element::BlockRole';

has level => (is => 'rw');
has title => (is => 'rw');
has priority => (is => 'rw');
has tags => (is => 'rw');
has is_todo => (is => 'rw');
has is_done => (is => 'rw');
has todo_state => (is => 'rw');
has statistics_cookie => (is => 'rw');

# old name, deprecated since 2014-07-17, will be removed in the future
sub todo_priority { shift->priority(@_) }

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
         $self->priority ? "[#".$self->priority."] " : "",
         $self->statistics_cookie ? "[".$self->statistics_cookie."] " : "",
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
    my ($self, $name) = @_;
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

sub get_drawer {
	my $self = shift;
	my $wanted_drawer_name = shift || "PROPERTIES";

	for my $d (@{$self->children||[]}) {
        log_trace("seeking $wanted_drawer_name drawer in child: %s (%s)", $d->as_string, ref($d));
		next unless ($d->isa('Org::Element::Drawer')
					 && $d->name eq $wanted_drawer_name
					 && $d->properties);
		return $d;
	}
}

sub get_property {
    my ($self, $name, $search_parent, $search_docprop) = @_;
    #$log->tracef("-> get_property(%s, search_par=%s)", $name, $search_parent);
    my $parent = $self->parent;

    my $propd = $self->get_drawer("PROPERTIES");
    return $propd->properties->{$name} if
        $propd && defined $propd->properties->{$name};

    if ($parent && $search_parent) {
        while ($parent) {
            if ($parent->isa('Org::Element::Headline')) {
                my $res = $parent->get_property($name, 0, 0);
                return $res if defined $res;
            }
            $parent = $parent->parent;
        }
    }

    if ($search_docprop // 1) {
        log_trace("Getting property from document's .properties");
        return $self->document->properties->{$name};
    }
    undef;
}

sub update_statistics_cookie {
    my $self = shift;

    my $statc = $self->statistics_cookie;
    return unless $statc;

    my $num_done = 0;
    my $num_total = 0;

    # count using checks on first-level list's children, or from first-level
    # subheadlines
    for my $chld (@{ $self->children // [] }) {
        if ($chld->isa("Org::Element::Headline")) {
            for my $el (@{ $self->children }) {
                next unless $el->isa("Org::Element::Headline");
                if ($el->is_todo) {
                    $num_total++;
                    $num_done++ if $el->is_done;
                }
            }
            last;
        } elsif ($chld->isa("Org::Element::List")) {
            for my $el (@{ $self->children }) {
                next unless $el->isa("Org::Element::List");
                for my $el2 (@{ $el->children }) {
                    next unless $el2->isa("Org::Element::ListItem");
                    my $state = $el2->check_state;
                    if (defined $state) {
                        $num_total++;
                        $num_done++ if $state eq 'X';
                    }
                }
            }
            last;
        }
    }

    undef $self->{_str}; # we modify content
    if ($statc =~ /%/) {
        $self->statistics_cookie(
            sprintf("%d%%", $num_total == 0 ? 0 : $num_done/$num_total * 100));
    } else {
        $self->statistics_cookie(sprintf("%d/%d", $num_done, $num_total));
    }
}

1;
# ABSTRACT: Represent Org headline

=for Pod::Coverage ^(header_as_string|as_string|todo_priority)$

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 level => INT

Level of headline (e.g. 1, 2, 3). Corresponds to the number of bullet stars.

=head2 title => OBJ

L<Org::Element::Text> representing the headline title

=head2 priority => STR

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

=head2 statistics_cookie => STR

Statistics cookie, e.g. '5/10' or '50%'. TODO: there might be more than one
statistics cookie.


=head1 METHODS

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

Search for property named $name in the PROPERTIES drawer. If $search_parent is
set to true (default is false), will also search in upper-level properties
(useful for searching for inherited property, like foo_ALL). Return undef if
property cannot be found.

Regardless of $search_parent setting, file-wide properties will be consulted if
property is not found in the headline's properties drawer.

=head2 $el->get_drawer([$drawer_name]) => VALUE

Return an entire drawer as an Org::Element::Drawer object. By default, return the
PROPERTIES drawer. If you want LOGBOOK or some other drawer, ask for it by name.

=head2 $el->update_statistics_cookie

Update the statistics cookies by recalculating the number of TODO and
checkboxes.

Will do nothing if the headline does not have any statistics cookie.

=cut
