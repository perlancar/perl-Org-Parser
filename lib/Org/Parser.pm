package Org::Parser;
# ABSTRACT: Parse Org documents

use 5.010;
use Moo;
use Log::Any '$log';

use File::Slurp;
use Org::Document;
use Scalar::Util qw(blessed);

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

# parse blocky elements: setting, blocks, header argument
sub _parse {
    my ($self, $str, $doc) = @_;
    $log->tracef('-> _parse(%s)', $str);

    $doc //= Org::Document->new(_parser => $self);
    if (!$self->_last_headline ) { $self->_last_headline ($doc)   }
    if (!$self->_last_headlines) { $self->_last_headlines([$doc]) }

    state $re  = qr/(?<block>    $ls_re \#\+BEGIN_(?<sname>\w+)
                                 (?:.|\R)*?
                                 \R\#\+END_\k<sname> $le_re) |
                   (?<setting>   $ls_re \#\+.* $le_re) |
                   (?<headline>  $ls_re \*+[ \t].* $le_re) |
                   (?<table>     (?: $ls_re [ \t]* \| [ \t]* \S.* $le_re)+) |
                   (?<drawer>    $ls_re [ \t]* :(?<drawer_name> \w+): [ \t]*\R
                                 (?:.|\R)*?
                                 $ls_re [ \t]* :END:) |
                   (?<other>     [^#*:|]+ | # to lump things more
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
                $self->parse_inline(join("", @other), $doc);
            }
            @other = ();
        }

        my $parent = $self->_last_headline;
        my $el;
        if ($+{block}) {
            require Org::Element::Block;
            $el = Org::Element::Block->new(
                document=>$doc, raw=>$+{block});
        } elsif ($+{setting}) {
            require Org::Element::Setting;
            $el = Org::Element::Setting->new(
                document=>$doc, raw=>$+{setting});
        } elsif ($+{table}) {
            require Org::Element::Table;
            $el = Org::Element::Table->new(
                document=>$doc, raw=>$+{table});
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
            for (my $i=$el->level-1; $i>=0; $i--) {
                $parent = $self->_last_headlines->[$i] and last;
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
        $self->parse_inline(join("", @other), $doc);
    }
    @other = ();

    $log->tracef('<- _parse()');
    $doc;
}

=head2 $orgp->parse_inline($str, $doc[, $parent])

Inline elements are elements that can be put under a heading, table cell,
heading title, etc. these include normal text (and text with markups),
timestamps, links, etc.

Found elements will be added into $parent's children. If $parent is not
specified, it will be set to $orgp->_last_headline (or, if undef, $doc).

=cut

sub parse_inline {
    my ($self, $str, $doc, $parent) = @_;
    $parent //= $self->_last_headline // $doc;

    $log->tracef("-> parse_inline(%s)", $str);
    state $re = qr/(?<timestamp_pair>          \[\d{4}-\d{2}-\d{2} \s[^\]]*\]--
                                               \[\d{4}-\d{2}-\d{2} \s[^\]]*\]) |
                   (?<timestamp>               \[\d{4}-\d{2}-\d{2} \s[^\]]*\]) |
                   (?<schedule_timestamp_pair> <\d{4}-\d{2}-\d{2}  \s[^>]*>--
                                               <\d{4}-\d{2}-\d{2}  \s[^>]*>) |
                   (?<schedule_timestamp>      <\d{4}-\d{2}-\d{2}  \s[^>]*>) |
                   # link
                   # (marked up) text
                   (?<other>                   [^\[<]+ | # to lump things more
                                               .+?)
                  /sxi;
    my @other;
    while ($str =~ /$re/g) {
        $log->tracef("match inline: %s", \%+);
        if (defined $+{other}) {
            push @other, $+{other};
            next;
        } else {
            if (@other) {
                $self->_parse_text(join("", @other), $doc, $parent);
            }
            @other = ();
        }

        my $el;
        if      ($+{timestamp_pair}) {
            require Org::Element::TimestampPair;
            $el = Org::Element::TimestampPair->new(
                document=>$doc, raw=>$+{timestamp_pair});
        } elsif ($+{timestamp}) {
            require Org::Element::Timestamp;
            $el = Org::Element::Timestamp->new(
                document=>$doc, raw=>$+{timestamp});
        } elsif ($+{schedule_timestamp_pair}) {
            require Org::Element::ScheduleTimestampPair;
            $el = Org::Element::ScheduleTimestampPair->new(
                document=>$doc, raw=>$+{schedule_timestamp_pair});
        } elsif ($+{schedule_timestamp}) {
            require Org::Element::ScheduleTimestamp;
            $el = Org::Element::ScheduleTimestamp->new(
                document=>$doc, raw=>$+{schedule_timestamp});
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
        $self->_parse_text(join("", @other), $doc, $parent);
    }
    @other = ();

    $log->tracef('<- parse_inline()');
}

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
    require Org::Element::Text;
    my ($self, $str, $doc, $parent) = @_;
    $parent //= $self->_last_headline // $doc;
    $log->tracef("-> _parse_text(%s)", $str);
    my $el = Org::Element::Text->new(
        raw => $str, document=>$doc, parent=>$parent);
    $parent->children([]) if !$parent->children;
    push @{$parent->children}, $el;
    $self->handler->($self, "element", {element=>$el}) if $self->handler;
}

sub __split_tags {
    [$_[0] =~ /:([^:]+)/g];
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

=item * Set table's caption, etc from settings

 #+CAPTION: A long table
 #+LABEL: tbl:long
 |...|...|
 |...|...|

Question: is this still valid caption?

 #+CAPTION: A long table
 some text
 #+LABEL: tbl:long
 some more text
 |...|...|
 |...|...|

=item * Parse text markups

=item * Parse headline percentages

=item * Parse {unordered,ordered,description,check) lists

=item * Process includes (#+INCLUDE)

=item * Parse buffer-wide header arguments (#+BABEL, 14.8.1)

=back


=head1 SEE ALSO

=cut

1;
