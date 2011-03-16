package Org::Parser;
# ABSTRACT: Parse Org documents

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

use File::Slurp;
use Scalar::Util qw(blessed);

use Moo;
has handler                 => (is => 'rw', default => sub{ sub{1} });
has raw                     => (is => 'rw');
has todo_states             => (is => 'rw', default => sub{[qw/TODO/]});
has done_states             => (is => 'rw', default => sub{[qw/DONE/]});
has priorities              => (is => 'rw', default => sub{[qw/A B C/]});
has drawers                 => (is => 'rw', default => sub{[
    qw/CLOCK LOGBOOK PROPERTIES/]});

my $tags_re = qr/:(?:[^:]+:)+/;
my $ls_     = qr/(?:(?<=[\015\012])|\A)/;
my $le      = qr/(?:\R|\z)/;

# parse blocks + settings + headlines
sub _parse {
    my ($self) = @_;
    my $raw = $self->raw;
    die "BUG: raw attribute has not been set" unless defined($raw);

    state $re  = qr/(?<block>    $ls_ \#\+BEGIN_(?<sname>\w+)
                                 (?:.|\R)*
                                 \R\#\+END_\k<sname> $le) |
                   (?<setting>   $ls_ \#\+.* $le) |
                   (?<headline>  $ls_ \*+[ \t].* $le) |
                   (?<other>     [^#*]+ | # to lump things more
                                 .+?)
                  /mx;

    my @other;
    while ($raw =~ /$re/g) {
        $log->tracef("match: %s", \%+);
        if (defined $+{other}) {
            push @other, $+{other};
            next;
        } else {
            if (@other) {
                $self->_parse2(join "", @other);
            }
            @other = ();
        }

        if ($+{block}) {
            $self->_parse_block($+{block});
        } elsif ($+{setting}) {
            $self->_parse_setting($+{setting});
        } elsif ($+{headline}) {
            $self->_parse_headline($+{headline});
        }
    }

    # remaining text
    if (@other) {
        $self->_parse2(join "", @other);
    }
    @other = ();
}

# parse text: timestamps, drawers
sub _parse2 {
    my ($self, $raw) = @_;
    $log->tracef("-> _parse2(%s)", $raw);
    state $re = qr/(?<timestamp_pair>          \[\d{4}-\d{2}-\d{2} \s[^\]]*\]--
                                               \[\d{4}-\d{2}-\d{2} \s[^\]]*\]) |
                   (?<timestamp>               \[\d{4}-\d{2}-\d{2} \s[^\]]*\]) |
                   (?<schedule_timestamp_pair> <\d{4}-\d{2}-\d{2}  \s[^>]*>--
                                               <\d{4}-\d{2}-\d{2}  \s[^>]*>) |
                   (?<schedule_timestamp>      <\d{4}-\d{2}-\d{2}  \s[^>]*>) |
                   (?<drawer>                  $ls_ [ \t]* :\w+: [ \t]*\R
                                               .*?
                                               $ls_ [ \t]* :END:) |
                   (?<other>                   [^\[<:]+ | # to lump things more
                                               .+?)
                  /sx;
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
                  /x;
    $raw =~ $re or die "Invalid syntax in drawer: $raw";
    my ($d, $rc) = ($1, $2);
    my $args = {element=>"drawer", drawer=>$d, raw=>$raw, raw_content=>$rc};
    $d ~~ @{ $self->drawers } or die "Unknown drawer name $d: $raw";

    if ($d eq 'PROPERTIES') {
        $args->{properties} = {};
        for (split /\R/, $rc) {
            next unless /\S/;
            die "Invalid line in PROPERTY drawer: $_"
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
    my ($setting, $raw_arg) = ($1, $2);
    my $args = {element=>'setting', setting=>$setting,
                raw_arg=>$raw_arg, raw=>$raw};
    if      ($setting eq 'ARCHIVE') {
    } elsif ($setting eq 'AUTHOR') {
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

sub _parse_block {
    my ($self, $raw) = @_;
    $log->tracef("-> _parse_block(%s)", $raw);
    state $re = qr/\A\#\+(?:BEGIN_(CENTER|COMMENT|EXAMPLE|QUOTE|SRC|VERSE))
                   (?:\s+(\S.*))\R # arg
                   ((?:.|\R)*)     # content
                   \#\+\w+\R?\z    # closing
                  /x;
    $raw =~ $re or die "Invalid/unknown block: $raw";
    $self->handler->($self, "element", {
        element=>"block", block=>$1,
        raw_arg=>$2//"", raw_content=>$3,
        raw=>$raw});
}

sub _parse_headline {
    my ($self, $raw) = @_;
    $log->tracef("-> _parse_headline(%s)", $raw);
    state $re = qr/\A(\*+)\s+(.*?)(?:\s+($tags_re))?\s*\R?\z/x;
    $raw =~ $re or die "Invalid headline syntax: $raw";
    my ($bullet, $title, $tags) = ($1, $2, $3);
    my $args = {element=>"headline", raw=>$raw, level=>length($bullet)};
    $args->{tags} = __split_tags($tags) if $tags;

    # XXX cache re
    my $todo_kw_re = "(?:".
        join("|", map {quotemeta}
                 @{$self->todo_states}, @{$self->done_states}) . ")";
    if ($title =~ s/^($todo_kw_re)\s+//) {
        my $state = $1;
        $args->{is_todo} = 1;
        $args->{todo_state} = $state;
        $args->{is_done} = 1 if $state ~~ @{ $self->done_states };
        # XXX cache re
        my $prio_re = "(?:".
            join("|", map {quotemeta} @{$self->priorities}) . ")";
        if ($title =~ s/\[#($prio_re)\]\s*//) {
            $args->{todo_priority} = $1;
        }
    }

    $args->{title} = $title;
    $self->handler->($self, "element", $args);
}

sub parse {
    my ($self, $arg) = @_;
    die "Please specify a defined argument to parse()\n" unless defined($arg);

    if (my $r = ref($arg)) {
        if ($r eq 'ARRAY') {
            $self->raw(join "", @$arg);
        } elsif ($r eq 'GLOB' || blessed($arg) && $arg->isa('IO::Handle')) {
            $self->raw(join "", <$arg>);
        } elsif ($r eq 'CODE') {
            my @chunks;
            while (defined(my $chunk = $arg->())) {
                push @chunks, $chunk;
            }
            $self->raw(join "", @chunks);
        } else {
            die "Invalid argument, please supply a ".
                "string|arrayref|coderef|filehandle\n";
        }
    } else {
        $self->raw($arg);
    }
    $self->_parse;
}

sub parse_file {
    my ($self, $filename) = @_;
    $self->raw(scalar read_file($filename));
    $self->_parse;
}

1;
__END__

=head1 SYNOPSIS

 use 5.010;
 use Org::Parser;
 use Data::Dump::OneLine qw(dump1);
 my $orgp = Org::Parser->new();
 $op->handler(sub {
     my ($orgp, $ev, $args) = @_;
     say "\$ev=$ev, $args=", dump1($args);
 });
 $op->parse(<<EOF);
 #+FILETAGS: :tag1:tag2:tag3:
 text1 ...
 * h1 1  :tag1:tag2:
 ** TODO h2 1
 ** DONE h2 2
 * h1 2
 text2 *bold* ...
 | a | b |
 |---+---|
 | 1 | 2 |
 | 3 | 4 |
 [[link][description]]
 - unordered
 - list
   1. ordered
   2. list
     * term1 :: description1
     * term2 :: description2
   3. back to ordered list
 - back to unordered list
 EOF

Will output something like:

 $ev:element, $args={element=>'setting', setting=>'FILETAGS', raw_arg=>':tag1:tag2:tag3', tags=>[qw/tag1 tag2 tag3/], raw=>"#+FILETAGS :tag1:tag2:tag3:\n"}
 $ev:element, $args={element=>'text', text=>"text1 ...\n", raw=>"text1 ...\n"}
 $ev:element, $args={element=>'headline', level=>1, title=>'h1 1', tags=>['tag1', 'tag2'], raw=>"* h1 1  :tag1:tag2:\n"}
 $ev:element, $args={element=>'headline', level=>2, title=>'h2 1', is_todo=>1, todo_state=>'TODO', raw=>"** TODO h2 1\n"}
 $ev:element, $args={element=>'headline', level=>2, title=>'h2 1', is_todo=>1, is_done=>1, todo_state=>'DONE', raw=>"** DONE h2 2\n"}
 $ev:element, $args={element=>'headline', level=>1, title=>'h1 2', raw=>"* h1 2\n"}
 $ev:element, $args={element=>'text', text=>'text2 ', raw=>"text2 "}
 $ev:element, $args={element=>'text', is_bold=>1, text=>"bold", raw=>"*bold*"}
 $ev:element, $args={element=>'text', text=>"...\n", raw=>"...\n"
 $ev:element, $args={element=>'table', table=>[['a', 'b'], '--', [1, 2], [3, 4]], raw=>"| a | b |\n|---+---|\n| 1 | 2 |\n| 3 | 4 |\n"}
 $ev:element, $args={element=>'link', target=>'link', description=>'description', raw=>'[[link][description]]'}
 $ev:element, $args={element=>'text', text=>"\n", raw=>"\n"}
 $ev:element, $args={element=>'list item', type=>'unordered',   level=>1, bullet=>'-',  seq=>1, item=>'unordered', raw=>"- unordered\n"}
 $ev:element, $args={element=>'list item', type=>'unordered',   level=>1, bullet=>'-',  seq=>2, item=>'list', raw=>"- list\n"}
 $ev:element, $args={element=>'list item', type=>'ordered',     level=>2, bullet=>'1.', seq=>1, item=>'ordered', raw=>"  1. ordered\n"}
 $ev:element, $args={element=>'list item', type=>'ordered',     level=>2, bullet=>'2.', seq=>2, item=>'list', raw=>"  2. list\n"}
 $ev:element, $args={element=>'list item', type=>'description', level=>3, bullet=>'*',  seq=>1, term=>'term1', description=>'description1', raw=>"    * term1 :: description1\n"}
 $ev:element, $args={element=>'list item', type=>'description', level=>3, bullet=>'*',  seq=>2, term=>'term2', description=>'description2', raw=>"    * term2 :: description2\n"}
 $ev:element, $args={element=>'list item', type=>'ordered',     level=>2, bullet=>'3.', seq=>3, item=>'back to ordered list', raw=>"  3. back to ordered list\n"}
 $ev:element, $args={element=>'list item', type=>'unordered',   level=>1, bullet=>'-',  seq=>3, item=>'back to unordered list', raw=>"- back to unordered list\n"}


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

=head2 handler => CODEREF

The handler which will be called repeatedly by the parser during parsing. The
default handler will do nothing ('sub{1}').

Handler will be passed these arguments:

 $orgp, $ev, \%args

$orgp is the parser instance, $ev is the type of event (currently only
'element') and %args are extra information depending on $ev and type of
elements. See the SYNOPSIS for the various content of %args.


=head1 METHODS

=head2 new()

Create a new parser instance.

=head2 $orgp->parse($str | $arrayref | $coderef | $filehandle)

Parse document (which can be contained in a scalar $str, an array of lines
$arrayref, a subroutine which will be called for chunks until it returns undef,
or a filehandle.

Will call handler (specified in 'handler' attribute) for each element being
parsed. See documentation for 'handler' attribute for more details.

Will die if there are syntax errors in documents.

=head2 $orgp->parse_file($filename)

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

=back


=head1 SEE ALSO

L<Org::Document>

=cut

1;
