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
# FEEDSTATUS

has _handler                => (is => 'rw');

our $tags_re      = qr/:(?:[^:]+:)+/;
my  $ls_re        = qr/(?:(?<=[\015\012])|\A)/;
my  $sp_bef_re    = qr/(?:(?<=\s)|\A)/s;
my  $sp_aft_re    = qr/(?:(?=\s)|\z)/s;
my  $le_re        = qr/(?:\R|\z)/;
our $arg_val_re   = qr/(?: '(?<squote> [^']*)' |
                         "(?<dquote> [^"]*)" |
                          (?<bare> \S+) ) \z
                    /x;
my $tstamp_re     = qr/(?:\[\d{4}-\d{2}-\d{2} \s+ [^\]]*\])/x;
my $act_tstamp_re = qr/(?:<\d{4}-\d{2}-\d{2} \s+ [^>]*>)/x;
my $text_re       =
    qr!
       (?<link>         \[\[(?<link_link> [^\]]+)\]
                        (?:\[(?<link_desc> (?:[^\]]|\R)+)\])?\]) |
       (?<radio_target> <<<(?<rt_target> [^>]+)>>>) |
       (?<target>       <<(?<t_target> [^>]+)>>) |
       (?<trange>       (?<trange_ts1> $tstamp_re)--
                        (?<trange_ts2> $tstamp_re)) |
       (?<tstamp>       $tstamp_re) |
       (?<act_trange>   (?<act_trange_ts1> $act_tstamp_re)--
                        (?<act_trange_ts2> $act_tstamp_re)) |
       (?<act_tstamp>   $act_tstamp_re) |
       (?<markup>       [*/+=~_]) |
       (?<plain_text>   (?:[^\[<*/+=~_]+|.+?)) # can be very slow
       #(?<plain_text>   .+?) # too dispersy
      !sxi;
my $block_elems_re = # top level elements
    qr/(?<block>     $ls_re \#\+BEGIN_(?<block_name>\w+)
                     (?:[ \t]+(?<block_raw_arg>\S.*))\R
                     (?<block_content>(?:.|\R)*?)
                     \R\#\+END_\k<block_name> $le_re) |
       (?<setting>   $ls_re \#\+
                     (?<setting_name> \w+): [ \t]+
                     (?<setting_raw_arg> .+) $le_re) |
       (?<comment>   $ls_re \#.*) |
       (?<headline>  $ls_re (?<h_bullet>\*+) [ \t]
                     (?<h_title>.*?)
                     (?:[ \t]+(?<h_tags> $tags_re))?[ \t]* $le_re) |
       (?<li_header> $ls_re (?<li_indent>[ \t]*)
                     (?<li_bullet>[+*-]) [ \t]+
                     (?<li_checkbox> \[(?<li_cbstate> [ X-])\])?) |
       (?<table>     (?: $ls_re [ \t]* \| [ \t]* \S.* $le_re)+) |
       (?<drawer>    $ls_re [ \t]* :(?<drawer_name> \w+): [ \t]*\R
                     (?<drawer_content>.|\R)*?
                     $ls_re [ \t]* :END:) |
       (?<text>      (?:[^#|:+*-]+|.|\n)+?) # can be very slow
       #(?<text>      .+?) # too dispersy
      /msxi;


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
                $el->is_done($state ~~ @{ $self->done_states } ? 1:0);

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
        $self->_trigger_handler("element", {element=>$el});
    }

    # remaining text
    if (@text) {
        $self->_add_text(join("", @text), $parent);
    }
    @text = ();

    $log->tracef('<- _parse()');
}

sub _add_text {
    require Org::Element::Text;
    my ($self, $str, $parent) = @_;
    $parent //= $self;
    $log->tracef("-> _add_text(%s)", $str);

    my @plain_text;
    while ($str =~ /$text_re/g) {
        $log->tracef("match text: %s", \%+);
        my $el;

        if (defined $+{plain_text}) {
            push @plain_text, $+{plain_text};
            next;
        } else {
            if (@plain_text) {
                $self->_add_plain_text(join("", @plain_text), $parent);
                @plain_text = ();
            }
        }

        if ($+{link}) {
            require Org::Element::Link;
            $el = Org::Element::Link->new(
                link=>$+{link_link}, description=>$+{link_desc});
        } elsif ($+{radio_target}) {
            require Org::Element::RadioTarget;
            $el = Org::Element::RadioTarget->new(target=>$+{rt_target});
        } elsif ($+{target}) {
            require Org::Element::Target;
            $el = Org::Element::Target->new(target=>$+{t_target});
        } elsif ($+{trange}) {
            require Org::Element::TimeRange;
            $el = Org::Element::TimeRange->new(
                _str => $+{trange},
                datetime1 => __parse_timestamp($+{trange_ts1}),
                datetime2 => __parse_timestamp($+{trange_ts2}),
            );
        } elsif ($+{tstamp}) {
            require Org::Element::Timestamp;
            $el = Org::Element::Timestamp->new(
                _str=>$+{tstamp},
                datetime => __parse_timestamp($+{tstamp}),
            );
        } elsif ($+{act_trange}) {
            require Org::Element::TimeRange;
            $el = Org::Element::TimeRange->new(
                _str=>$+{act_trange},
                is_active => 1,
                datetime1 => __parse_timestamp($+{act_tstamp_ts1}),
                datetime2 => __parse_timestamp($+{act_tstamp_ts2}),
            );
        } elsif ($+{act_tstamp}) {
            require Org::Element::Timestamp;
            $el = Org::Element::Timestamp->new(
                _str=>$+{act_tstamp},
                is_active => 1,
                datetime  => __parse_timestamp($+{act_tstamp}),
            );
        } elsif ($+{markup}) {
            require Org::Element::Text;
            $el = Org::Element::Text->new(
                style=>'', text=>$+{markup},
            );
            # temporary mark, we need to apply markup later
            $el->{_mu}++;
        }

        die "BUG2: no element" unless $el;
        $el->document($self);
        $el->parent($parent);
        $parent->children([]) if !$parent->children;
        push @{ $parent->children }, $el;
        $self->_trigger_handler("element", {element=>$el});
    }

    # remaining text
    if (@plain_text) {
        $parent->children([]) if !$parent->children;
        push @{$parent->children}, Org::Element::Text->new(
            text => join("", @plain_text), style=>'',
            document=>$self, parent=>$parent);
        @plain_text = ();
    }

    $log->tracef('<- _add_text()');
}

sub _add_plain_text {
    require Org::Element::Text;
    my ($self, $str, $parent) = @_;
    my $el = Org::Element::Text->new(
        document=>$self, parent=>$parent, style=>'', text=>$str);
    $parent->children([]) if !$parent->children;
    push @{ $parent->children }, $el;
    $self->_trigger_handler("element", {element=>$el});
}

sub _trigger_handler {
    my ($self, $ev, $args) = @_;
    return unless $self->_handler;
    $log->tracef("calling _handler(%s)", $ev);
    $self->_handler->($self, $ev, $args);
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
