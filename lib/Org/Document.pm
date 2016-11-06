package Org::Document;

# DATE
# VERSION

use 5.010;
use locale;
use Log::Any::IfLOG '$log';
use Moo;
use experimental 'smartmatch';
no if $] >= 5.021_006, warnings => "locale";
extends 'Org::Element';

use List::MoreUtils qw(firstidx);
use Time::HiRes qw(gettimeofday tv_interval);

has tags                    => (is => 'rw');
has todo_states             => (is => 'rw');
has done_states             => (is => 'rw');
has priorities              => (is => 'rw');
has drawer_names            => (is => 'rw');
has properties              => (is => 'rw');
has radio_targets           => (is => 'rw');

has time_zone               => (is => 'rw');

has ignore_unknown_settings => (is => 'rw');

our $tags_re       = qr/:(?:[A-Za-z0-9_@#%]+:)+/;
my  $ls_re         = qr/(?:(?<=[\015\012])|\A)/; # line start
my  $le_re         = qr/(?:\R|\z)/;              # line end
our $arg_re        = qr/(?: '(?<squote> [^']*)' |
                            "(?<dquote> [^"]*)" |
                            (?<bare> \S+) )
                       /x;
our $args_re       = qr/(?: $arg_re (?:[ \t]+ $arg_re)*)/x;
my  $tstamp_re     = qr/(?:\[\d{4}-\d{2}-\d{2} [^\n\]]*\])/x;
my  $act_tstamp_re = qr/(?: <\d{4}-\d{2}-\d{2} [^\n>]*  >)/x;
my  $fn_name_re    = qr/(?:[^ \t\n:\]]+)/x;
my  $text_re       =
    qr{
       (?<link>         \[\[(?<link_link> [^\]\n]+)\]
                        (?:\[(?<link_desc> (?:[^\]]|\R)+)\])?\]) |
       (?<radio_target> <<<(?<rt_target> [^>\n]+)>>>) |
       (?<target>       <<(?<t_target> [^>\n]+)>>) |

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

       (?<markup_start> (?:(?<=\s|\(|\{)|\A) # whitespace, open paren, open curly paren
                        [*/+=~_]
                        (?=\S)) |
       (?<markup_end>   (?<=\S)
                        [*/+=~_]
                        # actually emacs doesn't allow ! after markup
                        (?:(?=[ \t\n:;"',.!?\)*-])|\z)) |

       (?<plain_text>   (?:[^\[<*/+=~_\n]+|.+?))
       #(?<plain_text>   .+?) # too dispersy
      }sxi;

# XXX parser must be fixed: block elements have different precedence instead of
# flat like this. a headline has the highest precedence and a block or a drawer
# cannot contain a headline (e.g. "#+BEGIN_SRC foo\n* header\n#+END_SRC" should
# not contain a literal "* header" text but that is a headline. currently, a
# block or a drawer swallows a headline.

my $block_elems_re = # top level elements
    qr/(?<block>     $ls_re (?<block_begin_indent>[ \t]*)
                     \#\+BEGIN_(?<block_name>\w+)
                     (?:[ \t]+(?<block_raw_arg>[^\n]*))?\R
                     (?<block_content>(?:.|\R)*?)
                     \R(?<block_end_indent>[ \t]*)
                     \#\+END_\k<block_name> $le_re) |
       (?<setting>   $ls_re (?<setting_indent>[ \t]*) \#\+
                     (?<setting_name> \w+): (?: [ \t]+
                     (?<setting_raw_arg> [^\n]*))? $le_re) |
       (?<fixedw>    (?: $ls_re [ \t]* (?::[ ][^\n]* | :$) $le_re )+ ) |
       (?<comment>   $ls_re [ \t]*\#[^\n]*(?:\R\#[^\n]*)* (?:\R|\z)) |
       (?<headline>  $ls_re (?<h_bullet>\*+) [ \t]
                     (?<h_title>[^\n]*?)
                     (?:[ \t]+(?<h_tags> $tags_re))?[ \t]* $le_re) |
       (?<li_header> $ls_re (?<li_indent>[ \t]*)
                     (?<li_bullet>[+*-]|\d+\.) [ \t]+
                     (?<li_checkbox> \[(?<li_cbstate> [ X-])\])?
                     (?: (?<li_dt> [^\n]+?) [ ]::)?) |
       (?<table>     (?: $ls_re [ \t]* \| [ \t]* \S[^\n]* $le_re)+) |
       (?<drawer>    $ls_re [ \t]* :(?<drawer_name> \w+): [ \t]*\R
                     (?<drawer_content>(?:.|\R)*?)
                     $ls_re [ \t]* :END:) |
       (?<text>      (?:[^#|:+*0-9\n-]+|\n+|.)+?)
       #(?<text>      .+?) # too dispersy
      /msxi;

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
        if (/\A(?:[A-Za-z0-9_:-]+|\|)\z/) {
            push @s, $_;
        } elsif (/"/) {
            push @s, qq('$_');
        } else {
            push @s, qq("$_");
        }
    }
    join " ", @s;
}

sub BUILD {
    my ($self, $args) = @_;
    $self->document($self) unless $self->document;

    if (defined $args->{from_string}) {

        # NOTE: parsing is done twice. first pass will set settings (e.g. custom
        # todo keywords set by #+TODO), scan for radio targets. after that we
        # scan again to build the elements tree.

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
    my $t0 = [gettimeofday];

    my $last_el;

    my $last_headline;
    my $last_headlines = [$self]; # [$doc, $last_hl_level1, $last_hl_lvl2, ...]
    my $last_listitem;
    my $last_lists = []; # [last_List_obj_for_indent_level0, ...]
    my $parent;

    my @text;
    while ($str =~ /$block_elems_re/og) {
        $parent = $last_listitem // $last_headline // $self;
        #$log->tracef("TMP: parent=%s (%s)", ref($parent), $parent->_str);
        my %m = %+;
        next unless keys %m; # perlre bug?
        #if ($log->is_trace) {
        #    # profiler shows that this is very heavy, so commenting this out
        #    $log->tracef("TMP: match block element: %s", \%+) if $pass==2;
        #}

        if (defined $m{text}) {
            push @text, $m{text};
            next;
        } else {
            if (@text) {
                my $text = join("", @text);
                if ($last_el && $last_el->isa('Org::Element::ListItem')) {
                    # a list is broken by either: a) another list (where the
                    # bullet type or indent is different; handled in the
                    # handling of $m{li_header}) or b) by two blank lines, or c)
                    # by non-blank text that is indented less than or equal to
                    # the last list item's indent.

                    # a single blank line does not break a list. a text that is
                    # more indented than the last list item's indent will become
                    # the child of that list item.

                    my ($firstline, $restlines) = $text =~ /(.*?\r?\n)(.+)/s;
                    if ($restlines) {
                        $restlines =~ /\A([ \t]*)/;
                        my $rllevel = length($1);
                        my $listlevel = length($last_el->parent->indent);
                        if ($rllevel <= $listlevel) {
                            my $origparent = $parent;
                            # find lesser-indented list
                            $parent = $last_headline // $self;
                            for (my $i=$rllevel-1; $i>=0; $i--) {
                                if ($last_lists->[$i]) {
                                    $parent = $last_lists->[$i];
                                    last;
                                }
                            }
                            splice @$last_lists, $rllevel;
                            $self->_add_text($firstline, $origparent, $pass);
                            $self->_add_text($restlines, $parent, $pass);
                            goto SKIP1;
                        }
                    }
                }
                $self->_add_text($text, $parent, $pass);
              SKIP1:
                @text = ();
                $last_el = undef;
            }
        }

        my $el;
        if ($m{block} && $pass == 2) {

            require Org::Element::Block;
            $el = Org::Element::Block->new(
                _str=>$m{block},
                document=>$self, parent=>$parent,
                begin_indent=>$m{block_begin_indent},
                end_indent=>$m{block_end_indent},
                name=>$m{block_name}, args=>__parse_args($m{block_raw_arg}),
                raw_content=>$m{block_content},
            );

        } elsif ($m{setting}) {

            require Org::Element::Setting;
            if ($m{setting_indent} &&
                    !(uc($m{setting_name}) ~~
                          @{Org::Element::Setting->indentable_settings})) {
                push @text, $m{setting};
                next;
            } else {
                $el = Org::Element::Setting->new(
                    pass => $pass,
                    _str=>$m{setting},
                    document=>$self, parent=>$parent,
                    indent => $m{setting_indent},
                    name=>$m{setting_name},
                    args=>__parse_args($m{setting_raw_arg}),
                );
            }

        } elsif ($m{fixedw} && $pass == 2) {

            require Org::Element::FixedWidthSection;
            $el = Org::Element::FixedWidthSection->new(
                pass => $pass,
                _str=>$m{fixedw},
                document=>$self, parent=>$parent,
            );

        } elsif ($m{comment} && $pass == 2) {

            require Org::Element::Comment;
            $el = Org::Element::Comment->new(
                _str=>$m{comment},
                document=>$self, parent=>$parent,
            );

        } elsif ($m{table} && $pass == 2) {

            require Org::Element::Table;
            $el = Org::Element::Table->new(
                pass=>$pass,
                _str=>$m{table},
                document=>$self, parent=>$parent,
            );

        } elsif ($m{drawer} && $pass == 2) {

            require Org::Element::Drawer;
            my $raw_content = $m{drawer_content};
            $el = Org::Element::Drawer->new(
                document=>$self, parent=>$parent,
                name => uc($m{drawer_name}), pass => $pass,
            );
            $self->_add_text($raw_content, $el, $pass);

            # for properties, we also parse property lines from raw drawer
            # content. this is currently separate from normal Org text parsing,
            # i'm not clear yet on how to do this canonically.
            $el->_parse_properties($raw_content);

        } elsif ($m{li_header} && $pass == 2) {

            require Org::Element::List;
            require Org::Element::ListItem;

            my $level   = length($m{li_indent});
            my $bullet  = $m{li_bullet};
            my $indent  = $m{li_indent};
            my $dt      = $m{li_dt};
            my $cbstate = $m{li_cbstate};
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

        } elsif ($m{headline} && $pass == 2) {

            require Org::Element::Headline;
            my $level = length $m{h_bullet};

            # parent is upper-level headline
            $parent = undef;
            for (my $i=$level-1; $i>=0; $i--) {
                $parent = $last_headlines->[$i] and last;
            }
            $parent //= $self;

            $el = Org::Element::Headline->new(
                _str=>$m{headline},
                document=>$self, parent=>$parent,
                level=>$level,
            );
            $el->tags(__split_tags($m{h_tags})) if ($m{h_tags});
            my $title = $m{h_title};

            # recognize todo keyword
            my $todo_kw_re = "(?:".
                join("|", map {quotemeta}
                     "COMMENT",
                     @{$self->todo_states}, @{$self->done_states}) . ")";
            if ($title =~ s/^($todo_kw_re)(\s+|\W)/$2/) {
                my $state = $1;
                $title =~ s/^\s+//;
                $el->is_todo(1);
                $el->todo_state($state);
                $el->is_done($state ~~ @{ $self->done_states } ? 1:0);
            }

            # recognize priority cookie
            my $prio_re = "(?:".
                join("|", map {quotemeta} @{$self->priorities}) . ")";
            if ($title =~ s/\[#($prio_re)\]\s*//) {
                $el->priority($1);
            }

            # recognize statistics cookie
            if ($title =~ s!\[(\d+%|\d+/\d+)\]\s*!!o) {
                $el->statistics_cookie($1);
            }

            $el->title($self->_add_text_container($title, $parent, $pass));

            $last_headlines->[$el->level] = $el;
            splice @$last_headlines, $el->level+1;
            $last_headline  = $el;
            $last_listitem  = undef;
            $last_lists = [];
        }

        # we haven't caught other matches to become element
        die "BUG1: no element" unless $el || $pass != 2;

        $parent->children([]) if !$parent->children;
        push @{ $parent->children }, $el;
        $last_el = $el;
    }

    # remaining text
    if (@text) {
        $self->_add_text(join("", @text), $parent, $pass);
    }
    @text = ();

    $log->tracef('<- _parse(), elapsed time=%.3fs',
                 tv_interval($t0, [gettimeofday]));
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
    #$log->tracef("-> _add_text(%s, pass=%d)", $str, $pass);

    my @plain_text;
    while ($str =~ /$text_re/og) {
        my %m = %+;
        #if ($log->is_trace) {
        #    # profiler shows that this is very heavy, so commenting this out
        #    $log->tracef("TMP: match text: %s", \%+);
        #}
        my $el;

        if (defined $m{plain_text} && $pass == 2) {
            push @plain_text, $m{plain_text};
            next;
        } else {
            if (@plain_text) {
                $self->_add_plain_text(join("", @plain_text), $parent, $pass);
                @plain_text = ();
            }
        }

        if ($m{link} && $pass == 2) {
            require Org::Element::Link;
            $el = Org::Element::Link->new(
                document => $self, parent => $parent,
                link=>$m{link_link},
            );
            if (defined($m{link_desc}) && length($m{link_desc})) {
                $el->description(
                    $self->_add_text_container($m{link_desc},
                                               $el, $pass));
            }
        } elsif ($m{radio_target}) {
            require Org::Element::RadioTarget;
            $el = Org::Element::RadioTarget->new(
                pass => $pass,
                document => $self, parent => $parent,
                target=>$m{rt_target},
            );
        } elsif ($m{target} && $pass == 2) {
            require Org::Element::Target;
            $el = Org::Element::Target->new(
                document => $self, parent => $parent,
                target=>$m{t_target},
            );
        } elsif ($m{fn_num} && $pass == 2) {
            require Org::Element::Footnote;
            $el = Org::Element::Footnote->new(
                document => $self, parent => $parent,
                name=>$m{fn_num_num}, is_ref=>1,
            );
        } elsif ($m{fn_namedef} && $pass == 2) {
            require Org::Element::Footnote;
            $el = Org::Element::Footnote->new(
                document => $self, parent => $parent,
                name=>$m{fn_namedef_name},
                is_ref=>$m{fn_namedef_def} ? 0:1,
            );
            $el->def($self->_add_text_container($m{fn_namedef_def},
                                                $parent, $pass));
        } elsif ($m{fn_nameidef} && $pass == 2) {
            require Org::Element::Footnote;
            $el = Org::Element::Footnote->new(
                document => $self, parent => $parent,
                name=>$m{fn_nameidef_name},
                is_ref=>($m{fn_nameidef_def} ? 0:1) ||
                    !length($m{fn_nameidef_name}),
            );
            $el->def(length($m{fn_nameidef_def}) ?
                         $self->_add_text_container($m{fn_nameidef_def},
                                                    $parent, $pass) : undef);
        } elsif ($m{trange} && $pass == 2) {
            require Org::Element::TimeRange;
            require Org::Element::Timestamp;
            $el = Org::Element::TimeRange->new(
                document => $self, parent => $parent,
            );
            my $opts = {allow_event_duration=>0, allow_repeater=>0};
            $el->ts1(Org::Element::Timestamp->new(
                _str=>$m{trange_ts1}, document=>$self, parent=>$parent));
            $el->ts1->_parse_timestamp($m{trange_ts1}, $opts);
            $el->ts2(Org::Element::Timestamp->new(
                _str=>$m{trange_ts2}, document=>$self, parent=>$parent));
            $el->ts2->_parse_timestamp($m{trange_ts2}, $opts);
            $el->children([$el->ts1, $el->ts2]);
        } elsif ($m{tstamp} && $pass == 2) {
            require Org::Element::Timestamp;
            $el = Org::Element::Timestamp->new(
                _str => $m{tstamp}, document => $self, parent => $parent,
            );
            $el->_parse_timestamp($m{tstamp});
        } elsif ($m{act_trange} && $pass == 2) {
            require Org::Element::TimeRange;
            require Org::Element::Timestamp;
            $el = Org::Element::TimeRange->new(
                document => $self, parent => $parent,
            );
            my $opts = {allow_event_duration=>0, allow_repeater=>0};
            $el->ts1(Org::Element::Timestamp->new(
                _str=>$m{act_trange_ts1}, document=>$self, parent=>$parent));
            $el->ts1->_parse_timestamp($m{act_trange_ts1}, $opts);
            $el->ts2(Org::Element::Timestamp->new(
                _str=>$m{act_trange_ts2}, document=>$self, parent=>$parent));
            $el->ts2->_parse_timestamp($m{act_trange_ts2}, $opts);
            $el->children([$el->ts1, $el->ts2]);
        } elsif ($m{act_tstamp} && $pass == 2) {
            require Org::Element::Timestamp;
            $el = Org::Element::Timestamp->new(
                 _str => $m{act_tstamp}, document => $self, parent => $parent,
            );
            $el->_parse_timestamp($m{act_tstamp});
        } elsif ($m{markup_start} && $pass == 2) {
            require Org::Element::Text;
            $el = Org::Element::Text->new(
                document => $self, parent => $parent,
                style=>'', text=>$m{markup_start},
            );
            # temporary mark, we need to apply markup later
            $el->{_mu_start}++;
        } elsif ($m{markup_end} && $pass == 2) {
            require Org::Element::Text;
            $el = Org::Element::Text->new(
                document => $self, parent => $parent,
                style=>'', text=>$m{markup_end},
            );
            # temporary mark, we need to apply markup later
            $el->{_mu_end}++;
        }
        die "BUG2: no element" unless $el || $pass != 2;
        $parent->children([]) if !$parent->children;
        push @{ $parent->children }, $el;
    }

    # remaining text
    if (@plain_text && $pass == 2) {
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

    #$log->tracef('<- _add_text()');
}

# to keep parser's regexes simple and fast, we detect markup in regex rather
# simplistically (as text element) and then apply some more filtering & applying
# logic here

sub _apply_markup {
    #$log->trace("-> _apply_markup()");
    my ($self, $parent) = @_;
    my $last_index = 0;
    my $c = $parent->children or return;

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
            no warnings 'once';
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

sub __split_tags {
    [$_[0] =~ /:([^:]+)/g];
}

sub load_element_modules {
    require Module::List;
    require Module::Load;

    my $mm = Module::List::list_modules("Org::Element::", {list_modules=>1});
    for (keys %$mm) {
        Module::Load::load($_);
    }
}

sub cmp_priorities {
    my ($self, $p1, $p2) = @_;

    my $pp = $self->priorities;
    my $pos1 = firstidx {$_ eq $p1} @$pp;
    return undef unless $pos1 >= 0;
    my $pos2 = firstidx {$_ eq $p2} @$pp;
    return undef unless $pos2 >= 0;
    $pos1 <=> $pos2;
}

1;
# ABSTRACT: Represent an Org document
__END__

=head1 SYNOPSIS

 use Org::Document;

 # create a new Org document tree from string
 my $org = Org::Document->new(from_string => <<EOF);
 * heading 1a
 some text
 ** heading 2
 * heading 1b
 EOF


=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 tags => ARRAY

List of tags for this file, usually set via #+FILETAGS.

=head2 todo_states => ARRAY

List of known (action-requiring) todo states. Default is ['TODO'].

=head2 done_states => ARRAY

List of known done (non-action-requiring) states. Default is ['DONE'].

=head2 priorities => ARRAY

List of known priorities. Default is ['A', 'B', 'C'].

=head2 drawer_names => ARRAY

List of known drawer names. Default is [qw/CLOCK LOGBOOK PROPERTIES/].

=head2 properties => ARRAY

File-wide properties.

=head2 radio_targets => ARRAY

List of radio target text.

=head2 time_zone => ARRAY

If set, will be passed to DateTime->new() (e.g. by L<Org::Element::Timestamp>).

=head2 ignore_unknown_settings => bool

If set to true, unknown settings will not cause a parse failure.


=head1 METHODS

=for Pod::Coverage BUILD

=head2 new(from_string => ...)

Create object from string.

=head2 load_element_modules()

Load all Org::Element::* modules. This is useful when wanting to work with
element objects retrieved from serialization, where the element modules have not
been loaded.

=head2 cmp_priorities($p1, $p2) => -1|0|-1

Compare two priorities C<$p1> and C<$p2>. Return result like Perl's C<cmp>: 0 if
the two are the same, -1 if C<$p1> is of I<higher> priority (since it's more to
the left position in priority list, which is sorted highest-first) than C<$p2>,
and 1 if C<$p2> is of I<lower> priority than C<$p1>.

If either C<$p1> or C<$p2> has unknown priority, will return undef.

Examples:

 $doc->cmp_priorities('A', 'A')  # -> 0
 $doc->cmp_priorities('A', 'B')  # -> -1 (A is higher than B)
 $doc->cmp_priorities('C', 'B')  # -> 1 (C is lower than B)
 $doc->cmp_priorities('X', 'A')  # -> undef (X is unknown)

Note that X could be known if there is a C<#+PRIORITIES> setting which defines
it.

=cut
