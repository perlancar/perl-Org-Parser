package Org::Document;
# ABSTRACT: Represent an Org document

use 5.010;
use Log::Any '$log';
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 todo_states => ARRAY

List of known (action-requiring) todo states. Default is ['TODO'].

=cut

has todo_states             => (is => 'rw', default => sub{[qw/TODO/]});

=head2 done_states => ARRAY

List of known done (non-action-requiring) states. Default is ['DONE'].

=cut

has done_states             => (is => 'rw', default => sub{[qw/DONE/]});

=head2 priorities => ARRAY

List of known priorities. Default is ['A', 'B', 'C'].

=cut

has priorities              => (is => 'rw', default => sub{[qw/A B C/]});

=head2 drawers => ARRAY

List of known drawer names. Default is [qw/CLOCK LOGBOOK PROPERTIES/].

=cut

has drawers                 => (is => 'rw', default => sub{[
    qw/CLOCK LOGBOOK PROPERTIES/]});

has _handler                => (is => 'rw');

our $tags_re    = qr/:(?:[^:]+:)+/;
my  $ls_re      = qr/(?:(?<=[\015\012])|\A)/;
my  $sp_bef_re  = qr/(?:(?<=\s)|\A)/s;
my  $sp_aft_re  = qr/(?:(?=\s)|\z)/s;
my  $le_re      = qr/(?:\R|\z)/;
our $arg_val_re = qr/(?: '(?<squote> [^']*)' |
                         "(?<dquote> [^"]*)" |
                          (?<bare> \S+) ) \z
                    /x;
my $ts_re       = qr/(?:\[\d{4}-\d{2}-\d{2} \s+ [^\]]*\])/x;
my $sch_ts_re   = qr/(?:<\d{4}-\d{2}-\d{2} \s+ [^>]*>)/x;
my $markupable_re = # anything that can be *marked up*
    qr!(?:
       (?<link>         \[\[(?<link_link> [^\]]+)\]
                        (?:\[(?<link_desc> (?:[^\]]|\R)+)\])?\]) |
       (?<radio_target> <<<(?<rt_target> [^>]*)>>>) |
       (?<target>       <<(?<t_target> [^>]*)>>) |
       (?<ts_pair>      (?<ts_pair1> $ts_re)--
                        (?<ts_pair2> $ts_re)) |
       (?<ts>           $ts_re) |
       (?<sch_ts_pair>  (?<sch_ts_pair1> $sch_ts_re)--
                        (?<sch_ts_pair1> $sch_ts_re)) |
       (?<sch_ts>       $sch_ts_re) |
       (?<plain_text>   (?:[^\[<*/+=~_]+|.|\n)+?)
       )
      !xi;
my $text_re =
    qr!(?<marked>       $sp_bef_re (?<markup> [*/+=~_])
                        (?<m_content> $markupable_re+)
                        \k<markup> $sp_aft_re) |
       (?<unmarked>     (?:[^\[<*/+=~_]+|.|\n)+?)
      !x;
my $block_elems_re = # top level elements
    qr/(?<block>     $ls_re \#\+BEGIN_(?<block_name>\w+)
                     (?:\s+(?<block_raw_arg>\S.*))\R
                     (?<block_content>(?:.|\R)*?)
                     \R\#\+END_\k<block_name> $le_re) |
       (?<setting>   $ls_re \#\+
                     (?<setting_name> \w+): \s+
                     (?<setting_raw_arg> .+) $le_re) |
       (?<comment>   $ls_re \#.*) |
       (?<headline>  $ls_re (?<h_bullet>\*+) \s
                     (?<h_title>.*?)
                     (?:\s+(?<h_tags> $tags_re))?\s* $le_re) |
       (?<li_header> $ls_re (?<li_indent>\s*)
                     (?<li_bullet>[+*-]) \s+
                     (?<li_checkbox> \[(?<li_cbstate> [ X-])\])?) |
       (?<table>     (?: $ls_re \s* \| \s* \S.* $le_re)+) |
       (?<drawer>    $ls_re \s* :(?<drawer_name> \w+): \s*\R
                     (?<drawer_content>.|\R)*?
                     $ls_re \s* :END:) |
       (?<text>      (?:[^#*:|+\n-]+.|\n)+?)
      /mxi;


=head1 METHODS

=for Pod::Coverage BUILD

=cut

sub __get_arg_val {
    my $val = shift;
    $val =~ /\A $arg_val_re \z/ or return;
    if (defined $+{squote}) {
        return $+{squote};
    } elsif (defined $+{dquote}) {
        return $+{dquote};
    } else {
        return $+{bare};
    }
}

=head2 new(from_string => ...)

Create object from string.

=cut

sub BUILD {
    my ($self, $args) = @_;
    if (defined $args->{from_string}) {
        $self->_parse($args->{from_string});
    }
}

# parse blocky elements: setting, blocks, headline, drawer
sub _parse {
    my ($self, $str) = @_;
    $log->tracef('-> _parse(%s)', $str);

    my $last_headline;
    my $last_headlines = [$self]; # [doc, last_level1, last_level2, ...]
    my $last_li;
    my $last_lis = []; # [last_level0, last_level1, ...]
    my $parent;

    my @text;
    while ($str =~ /$block_elems_re/g) {
        $parent = $last_li // $last_headline // $self;
        #$log->tracef("TMP: parent=%s (%s)", ref($parent), $parent->_str);
        next unless keys %+; # perlre bug?
        $log->tracef("match block element: %s", \%+);

        if (defined $+{text}) {
            push @text, $+{text};
            next;
        } else {
            if (@text) {
                $self->_add_text(join("", @text), $parent);
            }
            @text = ();
        }

        my $el;
        if ($+{block}) {

            require Org::Element::Block;
            $el = Org::Element::Block->new(
                _str=>$+{block}, name=>$+{block_name}, raw_arg=>$+{block_arg},
                raw_content=>$+{block_content});

        } elsif ($+{setting}) {

            require Org::Element::Setting;
            $el = Org::Element::Setting->new(
                _str=>$+{setting}, name=>$+{setting_name},
                raw_arg=>$+{setting_raw_arg});

        } elsif ($+{table}) {

            require Org::Element::Table;
            $el = Org::Element::Table->new(_str=>$+{table});

        } elsif ($+{drawer}) {

            my $d = uc($+{drawer_name});
            if ($d eq 'PROPERTIES') {
                require Org::Element::Properties;
                $el = Org::Element::Properties->new(_str=>$+{drawer});
            } else {
                require Org::Element::Drawer;
                $el = Org::Element::Drawer->new(_str=>$+{drawer});
            }

        } elsif ($+{li_header}) {

            require Org::Element::ListItem;
            my $level = length($+{li_indent});
            $el = Org::Element::ListItem->new(
                indent=>$+{li_indent}, bullet=>$+{li_bullet});
            $el->check_state($+{li_cbstate}) if $+{li_cbstate};

            # parent is lesser-indented list item (or last headline)
            $parent = $last_headline // $self;
            for (my $i=$level-1; $i>=0; $i--) {
                if ($last_lis->[$i]) { $parent = $last_lis->[$i]; last }
            }
            $last_lis->[$level] = $el;
            $last_li = $el;

        } elsif ($+{headline}) {

            require Org::Element::Headline;
            $el = Org::Element::Headline->new(_str=>$+{headline});
            $el->tags(__split_tags($+{h_tags})) if ($+{h_tags});
            $el->level(length $+{h_bullet});
            my $title = $+{h_title};

            # recognize todo keyword. XXX cache re
            my $todo_kw_re = "(?:".
                join("|", map {quotemeta}
                         @{$self->todo_states}, @{$self->done_states}) . ")";
            if ($title =~ s/^($todo_kw_re)(\s+|\W)/$2/) {
                my $state = $1;
                $title =~ s/^\s+//;
                $el->is_todo(1);
                $el->todo_state($state);
                $el->is_done(1) if $el ~~ @{ $self->done_states };

                # recognize priority. XXX cache re
                my $prio_re = "(?:".
                    join("|", map {quotemeta} @{$self->priorities}) . ")";
                if ($title =~ s/\[#($prio_re)\]\s*//) {
                    $el->todo_priority($1);
                }
            }

            require Org::Element::Text;
            my $title_el = Org::Element::Text->new(
                document=>$self, parent=>$el, text=>'', style=>'');
            $self->_add_text($title, $title_el);
            $title_el = $title_el->children->[0] if
                $title_el->children && @{$title_el->children} == 1;
            $el->title($title_el);

            # parent is upper-level headline
            for (my $i=$el->level-1; $i>=0; $i--) {
                $parent = $last_headlines->[$i] and last;
            }
            $parent //= $self;
            $last_headlines->[$el->level] = $el;
            $last_headline  = $el;
            $last_li  = undef;
            $last_lis = [];
        }

        # we haven't caught other matches to become element
        die "BUG1: no element" unless $el;

        $el->document($self);
        $el->parent($parent);
        $parent->children([]) if !$parent->children;
        push @{ $parent->children }, $el;
        $self->_handler->($self, "element", {element=>$el})
            if $el && $self->_handler;
    }

    # remaining text
    if (@text) {
        $self->_add_text(join("", @text), $parent);
    }
    @text = ();

    $log->tracef('<- _parse()');
}

sub __allowable_marked_content {
    # emacs only tolerates one newline in marked up text
    my $s = shift;
    my $newlines = 0;
    $newlines++ while $s =~ /\R/g;
    $newlines <= 1;
}

sub _add_text {
    my ($self, $str, $parent) = @_;
    $parent //= $self;
    $log->tracef("-> _add_text(%s)", $str);

    my @um;
    while ($str =~ /$text_re/g) {
        $log->tracef("match text: %s", \%+);
        if ($+{marked}) {
            if (__allowable_marked_content($+{m_content})) {
                if (@um) {
                    $self->_add_markupable(join("", @um), $parent);
                    @um = ();
                }
                my $p2 = Org::Element::Text->new(
                    style => $Org::Element::Text::mu2style{ $+{markup} });
                $parent->children([]) unless $parent->children;
                push @{$parent->children}, $p2;
                $self->_add_markupable($+{m_content}, $p2);
            } else {
                push @um, $+{marked};
            }
        } else {
            push @um, $+{unmarked};
        }
    }

    if (@um) {
        $self->_add_markupable(join("", @um), $parent);
        @um = ();
    }
    $log->tracef("<- _add_text()");
}

sub _add_markupable {
    require Org::Element::Text;
    my ($self, $str, $parent) = @_;
    $parent //= $self;
    $log->tracef("-> _add_markupable(%s)", $str);

    my @plain_text;
    while ($str =~ /$markupable_re/g) {
        my $el;

        if (defined $+{plain_text}) {
            push @plain_text, $+{plain_text};
            next;
        } else {
            if (@plain_text) {
                $el = Org::Element::Text(
                    style=>'', text=>join("", @plain_text));
                goto ADD_CHILD_ELEM;
            }
            @plain_text = ();
        }

        if ($+{link}) {
            require Org::Element::Link;
            $el = Org::Element::Link->new(
                link=>$+{link_link}, description=>$+{link_desc});
        } elsif ($+{radio_target}) {
            require Org::Element::RadioTarget;
            $el = Org::Element::RadioTarget->new(target=>$+{rt_target});
        } elsif ($+{ts_pair}) {
            require Org::Element::Target;
            $el = Org::Element::Target->new(target=>$+{t_target});
        } elsif ($+{ts_pair}) {
            require Org::Element::TimestampPair;
            $el = Org::Element::TimestampPair->new(
                _str => $+{ts_pair},
                datetime1 => __parse_timestamp($+{ts_pair1}),
                datetime2 => __parse_timestamp($+{ts_pair2}),
            );
        } elsif ($+{ts}) {
            require Org::Element::Timestamp;
            $el = Org::Element::Timestamp->new(
                _str=>$+{ts},
                datetime => __parse_timestamp($+{ts}),
            );
        } elsif ($+{sch_ts_pair}) {
            require Org::Element::ScheduleTimestampPair;
            $el = Org::Element::ScheduleTimestampPair->new(
                _str=>$+{sch_ts_pair},
                datetime1 => __parse_timestamp($+{sch_ts_pair1}),
                datetime2 => __parse_timestamp($+{sch_ts_pair2}),
            );
        } elsif ($+{sch_ts}) {
            require Org::Element::ScheduleTimestamp;
            $el = Org::Element::ScheduleTimestamp->new(
                _str=>$+{sch_ts},
                datetime => __parse_timestamp($+{sch_ts}),
            );
        }

        die "BUG2: no markupable element" unless $el;
      ADD_CHILD_ELEM:
        $el->document($self);
        $el->parent($parent);
        $parent->children([]) if !$parent->children;
        push @{ $parent->children }, $el;
        $self->_handler->($self, "element", {element=>$el})
            if $el && $self->_handler;
    }

    # remaining text
    if (@plain_text) {
        $parent->children([]) if !$parent->children;
        push @{$parent->children}, Org::Element::Text->new(
            text => join("", @plain_text), style=>'',
            document=>$self, parent=>$parent);
        @plain_text = ();
    }

    $log->tracef('<- _add_markupable()');
}

# temporary place
sub __parse_timestamp {
    require DateTime;
    my ($ts) = @_;
    $ts =~ /^(?:\[|<)?(\d{4})-(\d{2})-(\d{2}) \s
            (?:\w{2,3}
                (?:\s (\d{2}):(\d{2}))?)?
            (?:\]|>)?
            $/x
        or die "Can't parse timestamp string: $ts";
    my %dt_args = (year => $1, month=>$2, day=>$3);
    if (defined($4)) { $dt_args{hour} = $4; $dt_args{minute} = $5 }
    my $res = DateTime->new(%dt_args);
    $res or die "Invalid date: $ts";
    $res;
}

sub __split_tags {
    [$_[0] =~ /:([^:]+)/g];
}

1;
__END__

=head1 SYNOPSIS

 use Org::Document;

 my $org = Org::Document->new(from_string => <<EOF);
 * heading 1a
 some text
 ** heading 2
 * heading 1b
 EOF


=head1 DESCRIPTION

Derived from Org::Element::Base.


=head1 SEE ALSO

L<Org::Parser>

=cut
