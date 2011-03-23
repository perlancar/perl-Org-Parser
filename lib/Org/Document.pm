package Org::Document;
# ABSTRACT: Represent an Org document

use 5.010;
use Log::Any '$log';
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 tags => ARRAY

List of tags for this file, usually set via #+FILETAGS.

=cut

has tags                    => (is => 'rw');

=head2 todo_states => ARRAY

List of known (action-requiring) todo states. Default is ['TODO'].

=cut

has todo_states             => (is => 'rw');

=head2 done_states => ARRAY

List of known done (non-action-requiring) states. Default is ['DONE'].

=cut

has done_states             => (is => 'rw');

=head2 priorities => ARRAY

List of known priorities. Default is ['A', 'B', 'C'].

=cut

has priorities              => (is => 'rw');

=head2 drawer_names => ARRAY

List of known drawer names. Default is [qw/CLOCK LOGBOOK PROPERTIES/].

=cut

has drawer_names            => (is => 'rw');

=head2 properties => ARRAY

File-wide properties.

=cut

has properties              => (is => 'rw');

=head2 radio_targets => ARRAY

List of radio target text.

=cut

has radio_targets           => (is => 'rw');

our $tags_re      = qr/:(?:[^:]+:)+/;
my  $ls_re        = qr/(?:(?<=[\015\012])|\A)/;
my  $le_re        = qr/(?:\R|\z)/;
our $arg_re       = qr/(?: '(?<squote> [^']*)' |
                           "(?<dquote> [^"]*)" |
                            (?<bare> \S+) )
                      /x;
our $args_re      = qr/(?: $arg_re (?:[ \t]+ $arg_re)*)/x;
my $tstamp_re     = qr/(?:\[\d{4}-\d{2}-\d{2} \s+ [^\]]*\])/x;
my $act_tstamp_re = qr/(?:<\d{4}-\d{2}-\d{2} \s+ [^>]*>)/x;
my $fn_name_re    = qr/(?:[^ \t\n:\]]+)/x;
my $text_re       =
    qr(
       (?<link>         \[\[(?<link_link> [^\]]+)\]
                        (?:\[(?<link_desc> (?:[^\]]|\R)+)\])?\]) |
       (?<radio_target> <<<(?<rt_target> [^>\n]+)>>>) |
       (?<target>       <<(?<t_target> [^>]+)>>) |

       # timestamp & time range
       (?<trange>       (?<trange_ts1> $tstamp_re)--
                        (?<trange_ts2> $tstamp_re)) |
       (?<tstamp>       $tstamp_re) |
       (?<act_trange>   (?<act_trange_ts1> $act_tstamp_re)--
                        (?<act_trange_ts2> $act_tstamp_re)) |
       (?<act_tstamp>   $act_tstamp_re) |

       # footnote (num, name + def, name + inline definition)
       (?<fn_num>       \[(?<fn_num_num>\d+)\]) |
       (?<fn_namedef>   $ls_re \[fn:(?<fn_namedef_name> $fn_name_re)\]
                        [ \t]* (?<fn_namedef_def> [^ \t\n]+)) |
       (?<fn_nameidef>  \[fn:(?<fn_nameidef_name> $fn_name_re?):?
                        (?<fn_nameidef_def> ([^\n\]]+)?)\]) |

       (?<markup_start> (?:(?<=\s)|\A)
                        [*/+=~_]
                        (?=\S)) |
       (?<markup_end>   (?<=\S)
                        [*/+=~_]
                        # actually emacs doesn't allow ! after markup
                        (?:(?=[ \t\n:;"',.!?\)*-])|\z)) |

       (?<plain_text>   (?:[^\[<*/+=~_]+|.+?))
       #(?<plain_text>   .+?) # too dispersy
      )sxi;
my $block_elems_re = # top level elements
    qr/(?<block>     $ls_re \#\+BEGIN_(?<block_name>\w+)
                     (?:[ \t]+(?<block_raw_arg>[^\n]*))?\R
                     (?<block_content>(?:.|\R)*?)
                     \R\#\+END_\k<block_name> $le_re) |
       (?<setting>   $ls_re \#\+
                     (?<setting_name> \w+): [ \t]+
                     (?<setting_raw_arg> [^\n]+) $le_re) |
       (?<comment>   $ls_re \#[^\n]*(?:\R\#[^\n]*)* (?:\R|\z)) |
       (?<headline>  $ls_re (?<h_bullet>\*+) [ \t]
                     (?<h_title>.*?)
                     (?:[ \t]+(?<h_tags> $tags_re))?[ \t]* $le_re) |
       (?<li_header> $ls_re (?<li_indent>[ \t]*)
                     (?<li_bullet>[+*-]|\d+\.) [ \t]+
                     (?<li_checkbox> \[(?<li_cbstate> [ X-])\])?
                     (?: (?<li_dt> [^\n]+?) [ \t]+ ::)?) |
       (?<table>     (?: $ls_re [ \t]* \| [ \t]* \S.* $le_re)+) |
       (?<drawer>    $ls_re [ \t]* :(?<drawer_name> \w+): [ \t]*\R
                     (?<drawer_content>(?:.|\R)*?)
                     $ls_re [ \t]* :END:) |
       (?<text>      (?:[^#|:+*0-9\n-]+|\n|.)+?)
       #(?<text>      .+?) # too dispersy
      /msxi;


=head1 METHODS

=for Pod::Coverage BUILD

=cut

sub _init_pass1 {
    my ($self) = @_;
    $self->tags([]);
    $self->todo_states([]);
    $self->done_states([]);
    $self->priorities([]);
    $self->properties({});
    $self->drawer_names([qw/CLOCK LOGBOOK PROPERTIES/]);
        # FEEDSTATUS
    $self->radio_targets([]);
}

sub _init_pass2 {
    my ($self) = @_;
    if (!@{ $self->todo_states } && !@{ $self->done_states }) {
        $self->todo_states(['TODO']);
        $self->done_states(['DONE']);
    }
    if (!@{ $self->priorities }) {
        $self->priorities([qw/A B C/]);
    }
    $self->children([]);
}

sub __parse_args {
    my $args = shift;
    return [] unless defined($args) && length($args);
    #$log->tracef("args = %s", $args);
    my @args;
    while ($args =~ /$arg_re (?:\s+|\z)/xg) {
        if (defined $+{squote}) {
            push @args, $+{squote};
        } elsif (defined $+{dquote}) {
            push @args, $+{dquote};
        } else {
            push @args, $+{bare};
        }
    }
    #$log->tracef("\\\@args = %s", \@args);
    \@args;
}

sub __format_args {
    my ($args) = @_;
    my @s;
    for (@$args) {
        if (/\A[A-Za-z0-9_:-]+\z/) {
            push @s, $_;
        } elsif (/"/) {
            push @s, qq('$_');
        } else {
            push @s, qq("$_");
        }
    }
    join " ", @s;
}

=head2 new(from_string => ...)

Create object from string.

=cut

sub BUILD {
    my ($self, $args) = @_;
    $self->document($self) unless $self->document;

    if (defined $args->{from_string}) {

        # NOTE: parsing is done twice. first pass will set settings (e.g. custom
        # todo keywords set by #+TODO), scan for radio targets, etc. after that
        # we scan again

        $self->_init_pass1();
        $self->_parse($args->{from_string}, 1);
        $self->_init_pass2();
        $self->_parse($args->{from_string}, 2);
    }
}

# parse blocky elements: setting, blocks, headline, drawer
sub _parse {
    my ($self, $str, $pass) = @_;
    $log->tracef('-> _parse(%s, pass=%d)', $str, $pass);

    my $last_headline;
    my $last_headlines = [$self]; # [$doc, $last_hl_level1, $last_hl_lvl2, ...]
    my $last_listitem;
    my $last_lists = []; # [last_List_obj_for_indent_level0, ...]
    my $parent;

    my @text;
    while ($str =~ /$block_elems_re/g) {
        $parent = $last_listitem // $last_headline // $self;
        #$log->tracef("TMP: parent=%s (%s)", ref($parent), $parent->_str);
        next unless keys %+; # perlre bug?
        $log->tracef("match block element: %s", \%+);

        if (defined $+{text}) {
            push @text, $+{text};
            next;
        } else {
            if (@text) {
                $self->_add_text(join("", @text), $parent, $pass);
            }
            @text = ();
        }

        my $el;
        if ($+{block}) {

            require Org::Element::Block;
            $el = Org::Element::Block->new(
                _str=>$+{block},
                document=>$self, parent=>$parent,
                name=>$+{block_name}, args=>__parse_args($+{block_raw_arg}),
                raw_content=>$+{block_content},
            );

        } elsif ($+{setting}) {

            require Org::Element::Setting;
            $el = Org::Element::Setting->new(
                pass => $pass,
                _str=>$+{setting},
                document=>$self, parent=>$parent,
                name=>$+{setting_name},
                args=>__parse_args($+{setting_raw_arg}),
            );

        } elsif ($+{comment}) {

            require Org::Element::Comment;
            $el = Org::Element::Comment->new(
                _str=>$+{comment},
                document=>$self, parent=>$parent,
            );

        } elsif ($+{table}) {

            require Org::Element::Table;
            $el = Org::Element::Table->new(
                pass=>$pass,
                _str=>$+{table},
                document=>$self, parent=>$parent,
            );

        } elsif ($+{drawer}) {

            require Org::Element::Drawer;
            my $raw_content = $+{drawer_content};
            $el = Org::Element::Drawer->new(
                document=>$self, parent=>$parent,
                name => uc($+{drawer_name}), pass => $pass,
            );
            $self->_add_text($raw_content, $el, $pass);

            # for properties, we also parse property lines from raw drawer
            # content. this is currently separate from normal Org text parsing,
            # i'm not clear yet on how to do this canonically.
            $el->_parse_properties($raw_content);

        } elsif ($+{li_header}) {

            require Org::Element::List;
            require Org::Element::ListItem;

            my $level   = length($+{li_indent});
            my $bullet  = $+{li_bullet};
            my $indent  = $+{li_indent};
            my $dt      = $+{li_dt};
            my $cbstate = $+{li_cbstate};
            my $type    = defined($dt) ? 'D' :
                $bullet =~ /^\d+\./ ? 'O' : 'U';
            my $bstyle  = $type eq 'O' ? '<N>.' : $bullet;

            # parent for list is lesser-indented list (or last headline)
            $parent = $last_headline // $self;
            for (my $i=$level-1; $i>=0; $i--) {
                if ($last_lists->[$i]) {
                    $parent = $last_lists->[$i];
                    last;
                }
            }

            my $list = $last_lists->[$level];
            if (!$list || $list->type ne $type ||
                    $list->bullet_style ne $bstyle) {
                $list = Org::Element::List->new(
                    document => $self, parent => $parent,
                    indent=>$indent, type=>$type, bullet_style=>$bstyle,
                );
                $last_lists->[$level] = $list;
                $parent->children([]) if !$parent->children;
                push @{ $parent->children }, $list;
            }
            $last_lists->[$level] = $list;

            # parent for list item is list
            $parent = $list;

            $el = Org::Element::ListItem->new(
                document=>$self, parent=>$list,
                indent=>$indent, bullet=>$bullet);
            $el->check_state($cbstate) if $cbstate;
            $el->desc_term($self->_add_text_container($dt, $list, $pass))
                if defined($dt);

            splice @$last_lists, $level+1;
            $last_listitem = $el;

        } elsif ($+{headline}) {

            require Org::Element::Headline;
            my $level = length $+{h_bullet};

            # parent is upper-level headline
            $parent = undef;
            for (my $i=$level-1; $i>=0; $i--) {
                $parent = $last_headlines->[$i] and last;
            }
            $parent //= $self;

            $el = Org::Element::Headline->new(
                _str=>$+{headline},
                document=>$self, parent=>$parent,
                level=>$level,
            );
            $el->tags(__split_tags($+{h_tags})) if ($+{h_tags});
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

            $el->title($self->_add_text_container($title, $parent, $pass));

            $last_headlines->[$el->level] = $el;
            splice @$last_headlines, $el->level+1;
            $last_headline  = $el;
            $last_listitem  = undef;
            $last_lists = [];
        }

        # we haven't caught other matches to become element
        die "BUG1: no element" unless $el;

        $parent->children([]) if !$parent->children;
        push @{ $parent->children }, $el;
    }

    # remaining text
    if (@text) {
        $self->_add_text(join("", @text), $parent, $pass);
    }
    @text = ();

    $log->tracef('<- _parse()');
}

sub _add_text_container {
    require Org::Element::Text;
    my ($self, $str, $parent, $pass) = @_;
    my $container = Org::Element::Text->new(
        document=>$self, parent=>$parent,
        text=>'', style=>'',
    );
    $self->_add_text($str, $container, $pass);
    $container = $container->children->[0] if
        $container->children && @{$container->children} == 1 &&
            $container->children->[0]->isa('Org::Element::Text');
    $container;
}

sub _add_text {
    require Org::Element::Text;
    my ($self, $str, $parent, $pass) = @_;
    $parent //= $self;
    $log->tracef("-> _add_text(%s, pass=%d)", $str, $pass);

    my @plain_text;
    while ($str =~ /$text_re/g) {
        $log->tracef("match text: %s", \%+);
        my $el;

        if (defined $+{plain_text}) {
            push @plain_text, $+{plain_text};
            next;
        } else {
            if (@plain_text) {
                $self->_add_plain_text(join("", @plain_text), $parent, $pass);
                @plain_text = ();
            }
        }

        if ($+{link}) {
            require Org::Element::Link;
            $el = Org::Element::Link->new(
                document => $self, parent => $parent,
                link=>$+{link_link}, description=>$+{link_desc},
            );
        } elsif ($+{radio_target}) {
            require Org::Element::RadioTarget;
            $el = Org::Element::RadioTarget->new(
                pass => $pass,
                document => $self, parent => $parent,
                target=>$+{rt_target},
            );
        } elsif ($+{target}) {
            require Org::Element::Target;
            $el = Org::Element::Target->new(
                document => $self, parent => $parent,
                target=>$+{t_target},
            );
        } elsif ($+{fn_num}) {
            require Org::Element::Footnote;
            $el = Org::Element::Footnote->new(
                document => $self, parent => $parent,
                name=>$+{fn_num_num}, is_ref=>1,
            );
        } elsif ($+{fn_namedef}) {
            require Org::Element::Footnote;
            $el = Org::Element::Footnote->new(
                document => $self, parent => $parent,
                name=>$+{fn_namedef_name},
                is_ref=>$+{fn_namedef_def} ? 0:1,
            );
            $el->def($self->_add_text_container($+{fn_namedef_def},
                                                $parent, $pass));
        } elsif ($+{fn_nameidef}) {
            require Org::Element::Footnote;
            $el = Org::Element::Footnote->new(
                document => $self, parent => $parent,
                name=>$+{fn_nameidef_name},
                is_ref=>($+{fn_nameidef_def} ? 0:1) ||
                    !length($+{fn_nameidef_name}),
            );
            $el->def(length($+{fn_nameidef_def}) ?
                         $self->_add_text_container($+{fn_nameidef_def},
                                                    $parent, $pass) : undef);
        } elsif ($+{trange}) {
            require Org::Element::TimeRange;
            $el = Org::Element::TimeRange->new(
                _str => $+{trange},
                document => $self, parent => $parent,
                datetime1 => __parse_timestamp($+{trange_ts1}),
                datetime2 => __parse_timestamp($+{trange_ts2}),
            );
        } elsif ($+{tstamp}) {
            require Org::Element::Timestamp;
            $el = Org::Element::Timestamp->new(
                _str=>$+{tstamp},
                document => $self, parent => $parent,
                datetime => __parse_timestamp($+{tstamp}),
            );
        } elsif ($+{act_trange}) {
            require Org::Element::TimeRange;
            $el = Org::Element::TimeRange->new(
                _str=>$+{act_trange},
                document => $self, parent => $parent,
                is_active => 1,
                datetime1 => __parse_timestamp($+{act_trange_ts1}),
                datetime2 => __parse_timestamp($+{act_trange_ts2}),
            );
        } elsif ($+{act_tstamp}) {
            require Org::Element::Timestamp;
            $el = Org::Element::Timestamp->new(
                _str=>$+{act_tstamp},
                document => $self, parent => $parent,
                is_active => 1,
                datetime  => __parse_timestamp($+{act_tstamp}),
            );
        } elsif ($+{markup_start}) {
            require Org::Element::Text;
            $el = Org::Element::Text->new(
                document => $self, parent => $parent,
                style=>'', text=>$+{markup_start},
            );
            # temporary mark, we need to apply markup later
            $el->{_mu_start}++;
        } elsif ($+{markup_end}) {
            require Org::Element::Text;
            $el = Org::Element::Text->new(
                document => $self, parent => $parent,
                style=>'', text=>$+{markup_end},
            );
            # temporary mark, we need to apply markup later
            $el->{_mu_end}++;
        }
        die "BUG2: no element" unless $el;
        $parent->children([]) if !$parent->children;
        push @{ $parent->children }, $el;
    }

    # remaining text
    if (@plain_text) {
        $parent->children([]) if !$parent->children;
        push @{$parent->children}, Org::Element::Text->new(
            text => join("", @plain_text), style=>'',
            document=>$self, parent=>$parent);
        @plain_text = ();
    }

    if ($pass == 2) {
        $self->_apply_markup($parent);
        if (@{$self->radio_targets}) {
            my $re = join "|", map {quotemeta} @{$self->radio_targets};
            $re = qr/(?:$re)/i;
            $self->_linkify_rt_recursive($re, $parent);
        }
        my $c = $parent->children // [];
    }

    $log->tracef('<- _add_text()');
}

# to keep parser's regexes simple and fast, we detect markup in regex rather
# simplistically (as text element) and then apply some more filtering & applying
# logic here

sub _apply_markup {
    #$log->trace("-> _apply_markup()");
    my ($self, $parent) = @_;
    my $last_index = 0;
    my $c = $parent->children;

    while (1) {
        #$log->tracef("text cluster = %s", [map {$_->as_string} @$c]);
        # find a new mu_start
        my $mu_start_index = -1;
        my $mu;
        for (my $i = $last_index; $i < @$c; $i++) {
            next unless $c->[$i]->{_mu_start};
            $mu_start_index = $i; $mu = $c->[$i]->text;
            #$log->tracef("found mu_start at %d (%s)", $i, $mu);
            last;
        }
        unless ($mu_start_index >= 0) {
            #$log->trace("no more mu_start found");
            last;
        }

        # check whether this is a valid markup (has text, has markup end, not
        # interspersed with non-text, no more > 1 newlines)
        my $mu_end_index = 0;
        my $newlines = 0;
        my $has_text;
        my $has_unmarkable;
        for (my $i=$mu_start_index+1; $i < @$c; $i++) {
            if ($c->[$i]->isa('Org::Element::Text')) {
                $has_text++;
            } elsif (1) {
            } else {
                $has_unmarkable++; last;
            }
            if ($c->[$i]->{_mu_end} && $c->[$i]->text eq $mu) {
                #$log->tracef("found mu_end at %d", $i);
                $mu_end_index = $i; last;
            }
            my $text = $c->[$i]->as_string;
            $newlines++ while $text =~ /\R/g;
            last if $newlines > 1;
        }
        my $valid = $has_text && !$has_unmarkable
            && $mu_end_index && $newlines <= 1;
        #$log->tracef("mu candidate: start=%d, end=%s, ".
        #             "has_text=%s, has_unmarkable=%s, newlines=%d, valid=%s",
        #             $mu_start_index, $mu_end_index,
        #             $has_text, $has_unmarkable, $newlines, $valid
        #         );
        if ($valid) {
            my $mu_el = Org::Element::Text->new(
                document => $self, parent => $parent,
                style=>$Org::Element::Text::mu2style{$mu}, text=>'',
            );
            my @c2 = splice @$c, $mu_start_index,
                $mu_end_index-$mu_start_index+1, $mu_el;
            #$log->tracef("grouping %s", [map {$_->text} @c2]);
            $mu_el->children(\@c2);
            shift @c2;
            pop @c2;
            for (@c2) {
                $_->{parent} = $mu_el;
            }
            $self->_merge_text_elements(\@c2);
            # squish if only one child
            if (@c2 == 1) {
                $mu_el->text($c2[0]->text);
                $mu_el->children(undef);
            }
        } else {
            undef $c->[$mu_start_index]->{_mu_start};
            $last_index++;
        }
    }
    $self->_merge_text_elements($c);
    #$log->trace("<- _apply_markup()");
}

sub _merge_text_elements {
    my ($self, $els) = @_;
    #$log->tracef("-> _merge_text_elements(%s)", [map {$_->as_string} @$els]);
    return unless @$els >= 2;
    my $i=-1;
    while (1) {
        $i++;
        last if $i >= @$els;
        next if $els->[$i]->children || !$els->[$i]->isa('Org::Element::Text');
        my $istyle = $els->[$i]->style // "";
        while (1) {
            last if $i+1 >= @$els || $els->[$i+1]->children ||
                !$els->[$i+1]->isa('Org::Element::Text');
            last if ($els->[$i+1]->style // "") ne $istyle;
            #$log->tracef("merging text[%d] '%s' with '%s'",
            #             $i, $els->[$i]->text, $els->[$i+1]->text);
            $els->[$i]->{text} .= $els->[$i+1]->{text} // "";
            splice @$els, $i+1, 1;
        }
    }
    #$log->tracef("merge result = %s", [map {$_->as_string} @$els]);
    #$log->trace("<- _merge_text_elements()");
}

sub _linkify_rt_recursive {
    require Org::Element::Text;
    require Org::Element::Link;
    my ($self, $re, $parent) = @_;
    my $c = $parent->children;
    return unless $c;
    for (my $i=0; $i<@$c; $i++) {
        my $el = $c->[$i];
        if ($el->isa('Org::Element::Text')) {
            my @split0 = split /\b($re)\b/, $el->text;
            next unless @split0 > 1;
            my @split;
            for my $s (@split0) {
                if ($s =~ /^$re$/) {
                    push @split, Org::Element::Link->new(
                        document=>$self, parent=>$parent,
                        link=>$s, description=>undef,
                        from_radio_target=>1,
                    );
                } elsif (length $s) {
                    push @split, Org::Element::Text->new(
                        document=>$self, parent=>$parent,
                        text=>$s, style=>$el->style,
                    );
                }
            }
            splice @$c, $i, 1, @split;
        }
        $self->_linkify_rt_recursive($re, $el);
    }
}

sub _add_plain_text {
    require Org::Element::Text;
    my ($self, $str, $parent, $pass) = @_;
    my $el = Org::Element::Text->new(
        document=>$self, parent=>$parent, style=>'', text=>$str);
    $parent->children([]) if !$parent->children;
    push @{ $parent->children }, $el;
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


