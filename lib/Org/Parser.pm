package Org::Parser;
# ABSTRACT: Parse Org documents

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

use File::Slurp;
use Org::Document;
use Scalar::Util qw(blessed);

use Moo;
has handler         => (is => 'rw');

has _last_headlines => (is => 'rw'); #[undef, $last_lvl1_h, $last_lvl2_h, ...]
has _last_headline  => (is => 'rw');

our $tags_re    = qr/:(?:[^:]+:)+/;
our $ls_re      = qr/(?:(?<=[\015\012])|\A)/;
our $le_re      = qr/(?:\R|\z)/;
our $arg_val_re = qr/(?: '(?<squote> [^']*)' |
                         "(?<dquote> [^"]*)" |
                         (?<bare> \S+) ) \z
                    /x;

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

# parse block'ish elements: setting, blocks, header argument
sub _parse {
    my ($self, $str, $doc) = @_;

    $doc //= Org::Document->new;
    if (!$self->_last_headlines) { $self->_last_headlines([undef]) }

    state $re  = qr/(?<block>    $ls_re \#\+BEGIN_(?<sname>\w+)
                                 (?:.|\R)*
                                 \R\#\+END_\k<sname> $le_re) |
                   (?<setting>   $ls_re \#\+.* $le_re) |
                   (?<headline>  $ls_re \*+[ \t].* $le_re) |
                   (?<drawer>    $ls_re [ \t]* :(?<drawer_name> \w+): [ \t]*\R
                                 .*?
                                 $ls_re [ \t]* :END:) |
                   (?<other>     [^#*:]+ | # to lump things more
                                 .+?)
                  /mxi;

    my @other;
    while ($str =~ /$re/g) {
        $log->tracef("match: %s", \%+);
        if (defined $+{other}) {
            push @other, $+{other};
            next;
        } else {
            if (@other) {
                $self->_parse_inline(join("", @other), $doc);
            }
            @other = ();
        }

        my $parent = $self->_last_headline // $doc;
        my $el;
        if ($+{block}) {
            require Org::Element::Block;
            $el = Org::Element::Block->new(
                document=>$doc, raw=>$+{block});
        } elsif ($+{setting}) {
            require Org::Element::Setting;
            $el = Org::Element::Block->new(
                document=>$doc, raw=>$+{setting});
        } elsif ($+{drawer}) {
            my $d = uc($+{drawer_name});
            if ($d eq 'PROPERTIES') {
                require Org::Element::Properties;
                $el = Org::Element::Properties->new(
                    document=>$doc, raw=>$+{drawer});
            } else {
                require Org::Element::Drawer;
                $el = Org::Element::Drawer->new(
                    document=>$doc, raw=>$+{drawer});
            }
        } elsif ($+{headline}) {
            require Org::Element::Headline;
            $el = Org::Element::Headline->new(
                document=>$doc, raw=>$+{headline});
            if ($el->level > 1 &&
                    ($parent = $self->_last_headlines->[$el->level - 1])) {
            } else {
                $parent = $doc;
            }
            $self->_last_headlines->[$el->level] = $el;
            $self->_last_headline($el);
        }
        $el->parent($parent);
        $parent->children([]) if !$parent->children;
        push @{ $parent->children }, $el;
        $self->handler->($self, "element", {element=>$el})
            if $el && $self->handler;
        $el = undef;
    }

    # remaining text
    if (@other) {
        $self->_parse_inline(join "", @other);
    }
    @other = ();

    $doc;
}

# parse inline elements: timestamps, markups, ...
sub _parse_inline {
    my ($self, $raw) = @_;
    $log->tracef("-> _parse2(%s)", $raw);
    state $re = qr/(?<timestamp_pair>          \[\d{4}-\d{2}-\d{2} \s[^\]]*\]--
                                               \[\d{4}-\d{2}-\d{2} \s[^\]]*\]) |
                   (?<timestamp>               \[\d{4}-\d{2}-\d{2} \s[^\]]*\]) |
                   (?<schedule_timestamp_pair> <\d{4}-\d{2}-\d{2}  \s[^>]*>--
                                               <\d{4}-\d{2}-\d{2}  \s[^>]*>) |
                   (?<schedule_timestamp>      <\d{4}-\d{2}-\d{2}  \s[^>]*>) |
                   (?<other>                   [^\[<]+ | # to lump things more
                                               .+?)
                  /sxi;
    my @other;
    while ($raw =~ /$re/g) {
        $log->tracef("match: %s", \%+);
        if (defined $+{other}) {
            push @other, $+{other};
            next;
        } else {
            if (@other) {
                $self->_parse_text(join "", @other);
            }
            @other = ();
        }

        if      ($+{timestamp_pair}) {
            $self->_parse_timestamp_pair($+{timestamp_pair});
        } elsif ($+{timestamp}) {
            $self->_parse_timestamp($+{timestamp});
        } elsif ($+{schedule_timestamp_pair}) {
            $self->_parse_schedule_timestamp_pair(
                $+{schedule_timestamp_pair});
        } elsif ($+{schedule_timestamp}) {
            $self->_parse_schedule_timestamp($+{schedule_timestamp});
        } elsif ($+{drawer}) {
            $self->_parse_drawer($+{drawer});
        }
    }

    # remaining text
    if (@other) {
        $self->_parse_text(join "", @other);
    }
    @other = ();
}

# XXX parse3? parse2? links, markups (*bold*, _underline_, /italic/, ~verbatim~,
# =code=, +strike+)

sub __parse_timestamp {
    require DateTime;
    my ($ts) = @_;
    $ts =~ /^(\d{4})-(\d{2})-(\d{2}) \s
            (?:\w{2,3}
                (?:\s (\d{2}):(\d{2}))?)?$/x
        or return;
    my %dt_args = (year => $1, month=>$2, day=>$3);
    if (defined($4)) { $dt_args{hour} = $4; $dt_args{minute} = $5 }
    DateTime->new(%dt_args);
}

sub _parse_text {
    my ($self, $raw) = @_;
    $self->handler->($self, "element", {element=>"text", raw=>$raw});
}

sub _parse_timestamp_pair {
    my ($self, $raw) = @_;
    warn "Sorry, parsing timestamp pair ($raw) not yet implemented";
}

sub _parse_timestamp {
    my ($self, $raw) = @_;
    warn "Sorry, parsing timestamp ($raw) not yet implemented";
}

sub _parse_schedule_timestamp_pair {
    my ($self, $raw) = @_;
    warn "Sorry, parsing schedule timestamp pair ($raw) not yet implemented";
}

sub _parse_schedule_timestamp {
    my ($self, $raw) = @_;
    state $re = qr/^<(.+)>$/;
    $raw =~ $re or die "Invalid syntax in timestamp: $raw";
    my $args = {element => "schedule timestamp", raw=>$raw};
    $args->{timestamp} = __parse_timestamp($1)
        or die "Can't parse timestamp $1";
    $self->handler->($self, "element", $args);
}

sub _parse_drawer {
    my ($self, $raw) = @_;
    $log->tracef("-> _parse_drawer(%s)", $raw);
    state $re = qr/\A\s*:(\w+):\s*\R
                   ((?:.|\R)*?)    # content
                   [ \t]*:END:\z   # closing
                  /xi;
    $raw =~ $re or die "Invalid syntax in drawer: $raw";
    my ($d, $rc) = (uc($1), $2);
    my $args = {element=>"drawer", drawer=>$d, raw=>$raw, raw_content=>$rc};
    $d ~~ @{ $self->drawers } or die "Unknown drawer name $d: $raw";

    if ($d eq 'PROPERTIES') {
        $args->{properties} = {};
        for (split /\R/, $rc) {
            next unless /\S/;
            die "Invalid line in PROPERTIES drawer: $_"
                unless /^\s*:(\w+):\s+(.+?)\s*$/;
            $args->{properties}{$1} = $2;
        }
    }

    $self->handler->($self, "element", $args);
}

sub __split_tags {
    [$_[0] =~ /:([^:]+)/g];
}

sub _parse_setting {
    my ($self, $raw) = @_;
    $log->tracef("-> _parse_setting(%s)", $raw);
    # XXX what's the syntax for several settings in a single line? for now we
    # assume one setting per line
    state $re = qr/\A\#\+(\w+): \s+ (.+?) \s* \R?\z/x;
    $raw =~ $re or die "Invalid setting syntax: $raw";
    my ($setting, $raw_arg) = (uc($1), $2);
    my $args = {element=>'setting', setting=>$setting,
                raw_arg=>$raw_arg, raw=>$raw};
    if      ($setting eq 'ARCHIVE') {
    } elsif ($setting eq 'AUTHOR') {
    } elsif ($setting eq 'BABEL') {
    } elsif ($setting eq 'CALL') {
    } elsif ($setting eq 'CAPTION') {
    } elsif ($setting eq 'BIND') {
    } elsif ($setting eq 'CATEGORY') {
    } elsif ($setting eq 'COLUMNS') {
    } elsif ($setting eq 'CONSTANTS') {
    } elsif ($setting eq 'DATE') {
    } elsif ($setting eq 'DESCRIPTION') {
    } elsif ($setting eq 'DRAWERS') {
        my $d = [split /\s+/, $raw_arg];
        $args->{drawers} = $d;
        for (@$d) {
            push @{ $self->drawers }, $_ unless $_ ~~ @{ $self->drawers };
        }
    } elsif ($setting eq 'EMAIL') {
    } elsif ($setting eq 'EXPORT_EXCLUDE_TAGS') {
    } elsif ($setting eq 'EXPORT_SELECT_TAGS') {
    } elsif ($setting eq 'FILETAGS') {
        $raw_arg =~ /^$tags_re$/ or
            die "Invalid argument syntax for FILEARGS: $raw";
        $args->{tags} = __split_tags($raw_arg);
    } elsif ($setting eq 'INCLUDE') {
    } elsif ($setting eq 'INDEX') {
    } elsif ($setting eq 'KEYWORDS') {
    } elsif ($setting eq 'LABEL') {
    } elsif ($setting eq 'LANGUAGE') {
    } elsif ($setting eq 'LATEX_HEADER') {
    } elsif ($setting eq 'LINK') {
    } elsif ($setting eq 'LINK_HOME') {
    } elsif ($setting eq 'LINK_UP') {
    } elsif ($setting eq 'OPTIONS') {
    } elsif ($setting eq 'PRIORITIES') {
        my $p = [split /\s+/, $raw_arg];
        $args->{priorities} = $p;
        $self->priorities($p);
    } elsif ($setting eq 'PROPERTY') {
        $raw_arg =~ /(\w+)\s+($arg_val_re)$/
            or die "Invalid argument for PROPERTY setting, ".
                "please use 'NAME VALUE': $raw_arg";
        $args->{property_name} = $1;
        $args->{property_value} = __get_arg_val($2);
    } elsif ($setting =~ /^(SEQ_TODO|TODO|TYP_TODO)$/) {
        my $done;
        my @args = split /\s+/, $raw_arg;
        $args->{states} = \@args;
        for (my $i=0; $i<@args; $i++) {
            my $arg = $args[$i];
            if ($arg eq '|') { $done++; next }
            $done++ if !$done && @args > 1 && $i == @args-1;
            my $ary = $done ? $self->done_states : $self->todo_states;
            push @$ary, $arg unless $arg ~~ @$ary;
        }
    } elsif ($setting eq 'SETUPFILE') {
    } elsif ($setting eq 'STARTUP') {
    } elsif ($setting eq 'STYLE') {
    } elsif ($setting eq 'TAGS') {
    } elsif ($setting eq 'TBLFM') {
    } elsif ($setting eq 'TEXT') {
    } elsif ($setting eq 'TITLE') {
    } elsif ($setting eq 'XSLT') {
    } else {
        die "Unknown setting $setting: $raw";
    }
    $self->handler->($self, "element", $args);
}

sub parse {
    my ($self, $arg) = @_;
    die "Please specify a defined argument to parse()\n" unless defined($arg);

    my $str;
    my $r = ref($arg);
    if (!$r) {
        $str = $arg;
    } elsif ($r eq 'ARRAY') {
        $str = join "", @$arg;
    } elsif ($r eq 'GLOB' || blessed($arg) && $arg->isa('IO::Handle')) {
        $str = join "", <$arg>;
    } elsif ($r eq 'CODE') {
        my @chunks;
        while (defined(my $chunk = $arg->())) {
            push @chunks, $chunk;
        }
        $str = join "", @chunks;
    } else {
        die "Invalid argument, please supply a ".
            "string|arrayref|coderef|filehandle\n";
    }
    $self->_parse($str);
}

sub parse_file {
    my ($self, $filename) = @_;
    $self->_parse(scalar read_file($filename));
}

1;
__END__

=head1 SYNOPSIS

 use 5.010;
 use Org::Parser;
 my $orgp = Org::Parser->new();

 # parse into a document object
 my $doc  = $orgp->parse_file("$ENV{HOME}/todo.org");

 # print out elements while parsing
 $orgp->handler(sub {
     my ($orgp, $event, @args) = @_;
     next unless $event eq 'element';
     my $el = shift @args;
     next unless $el->isa('Org::Element::Headline') &&
         $el->is_todo && !$el->is_done;
     say "found todo item: ", $el->title->as_string;
 });
 $orgp->parse(<<EOF);
 * heading1a
 ** TODO heading2a
 ** DONE heading2b
 * TODO heading1b
 * heading1c
 EOF

will print something like:

 found todo item: heading2a
 found todo item: heading1b


=head1 DESCRIPTION

This module parses Org documents. See http://orgmode.org/ for more details on
Org documents.

This module uses L<Log::Any> logging framework.

This module uses L<Moo> object system.

B<NOTE: This module is in alpha stage. See L</"BUGS/TODO/LIMITATIONS"> for the
list of stuffs not yet implemented.>

Already implemented/parsed:

=over 4

=item * in-buffer settings

=item * blocks

=item * headlines & TODO items

Including custom TODO keywords, custom priorities

=item * schedule timestamps (subset of)

=item * drawers & properties

=back


=head1 ATTRIBUTES

=head2 handler => CODEREF (default undef)

If set, the handler which will be called repeatedly by the parser during
parsing. This can be used to quickly filter/extract wanted elements (e.g.
headlines, timestamps, etc) from an Org document.

Handler will be passed these arguments:

 $orgp, $event, $args

$orgp is the parser instance, $event is the type of event (currently only
'element', triggered after the parser parses an element) and $args is a hashref
containing extra information depending on $event and type of elements. For
$event == 'element', $args->{element} will be set to the element object.


=head1 METHODS

=head2 new()

Create a new parser instance.

=head2 $orgp->parse($str | $arrayref | $coderef | $filehandle) => $doc

Parse document (which can be contained in a scalar $str, an array of lines
$arrayref, a subroutine which will be called for chunks until it returns undef,
or a filehandle).

Returns L<Org::Document> object.

If 'handler' attribute is specified, will call handler repeatedly during
parsing. See the 'handler' attribute for more details.

Will die if there are syntax errors in documents.

=head2 $orgp->parse_file($filename) => $doc

Just like parse(), but will load document from file instead.


=head1 BUGS/TODO/LIMITATIONS

=over 4

=item * Single-pass parser

Parser is currently a single-pass parser, so you need to preset stuffs before
using them. For example, when declaring custom TODO keywords:

 #+TODO: TODO | DONE
 #+TODO: BUG WISHLIST | FIXED CANTREPRO

 * FIXED blah

and not:

 * FIXED blah (at this point, custom TODO keywords not yet recognized)

 #+TODO: TODO | DONE
 #+TODO: BUG WISHLIST | FIXED CANTREPRO

=item * What's the syntax for multiple in-buffer settings on a single line?

Currently the parser assumes a single in-buffer settings per line

=item * Difference between TYP_TODO and TODO/SEQ_TODO?

Currently we assume it to be the same as the other two.

=item * Parse link & link abbreviations (#+LINK)

=item * Parse timestamps & timestamp pairs

=item * Parse repeats in schedule timestamps

=item * Parse tables

=item * Parse text markups

=item * Parse headline percentages

=item * Parse {unordered,ordered,description,check) lists

=item * Process includes (#+INCLUDE)

=item * Parse buffer-wide header arguments (#+BABEL, 14.8.1)

=back


=head1 SEE ALSO

=cut

1;
