package Org::Parser;

# DATE
# VERSION

use 5.010001;
use Moo;

use Org::Document;
use Scalar::Util qw(blessed);

sub parse {
    my ($self, $arg, $opts) = @_;
    die "Please specify a defined argument to parse()\n" unless defined($arg);

    $opts //= {};

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
    Org::Document->new(
        from_string=>$str,
        time_zone=>$opts->{time_zone},
        ignore_unknown_settings=>$opts->{ignore_unknown_settings},
    );
}

sub parse_file {
    require File::Slurper;
    my ($self, $filename, $opts) = @_;
    $opts //= {};

    state $loaded;

    my $content = File::Slurper::read_text($filename);

    my $cf = $opts->{cache_file}; # old option, new option is 'cache' (automatic setting of cache file)
    my $doc;
    my $cache; # undef = no caching; 0 = not cached, should cache; 1 = cached
    if (!$cf && ($opts->{cache} // $ENV{PERL_ORG_PARSER_CACHE})) {
        require Cwd;
        require Digest::MD5;
        my @dirs = ("$ENV{HOME}/.cache/perl-org-parser", $ENV{HOME});
        my $dir;
        for (@dirs) {
            if (-d $_) { $dir = $_; last }
            elsif (mkdir $_) { $dir = $_; last }
        }
        die "Can't find a suitable cache directory" unless $dir;
        my $abs = Cwd::abs_path($filename) or die "Can't find $filename";
        my $base = $abs; $base =~ s!.+/!!;
        $cf = "$dir/$base.".Digest::MD5::md5_hex($abs).".storable";
    }
    if ($cf) {
        require Storable;
        $cache = !!((-e $cf) && (-M $cf) <= (-M $filename));
        if ($cache) {
            eval {
                $doc = Storable::retrieve($cf);
                $doc->load_element_modules unless $loaded++;
            };
            if ($@) {
                warn "Failed retrieving document from cache: $@, reparsing ...";
                $cache = 0;
            }
        }
    }

    $doc = $self->parse($content, $opts) unless $cache;
    if (defined($cache) && !$cache) {
        require Storable;
        for ($doc->find('Timestamp')) {
            $_->clear_parse_result;
        }
        Storable::store($doc, $cf);
    }

    $doc;
}

1;
# ABSTRACT: Parse Org documents
__END__

=head1 SYNOPSIS

 use 5.010;
 use Org::Parser;
 my $orgp = Org::Parser->new();

 # parse a file
 my $doc = $orgp->parse_file("$ENV{HOME}/todo.org");

 # parse a string
 $doc = $orgp->parse(<<EOF);
 #+TODO: TODO | DONE CANCELLED
 <<<radio target>>>
 * heading1a
 ** TODO heading2a
 SCHEDULED: <2011-03-31 Thu>
 [[some][link]]
 ** DONE heading2b
 [2011-03-18 ]
 this will become a link: radio target
 * TODO heading1b *bold*
 - some
 - plain
 - list
 - [ ] with /checkbox/
   * and
   * sublist
 * CANCELLED heading1c
 + definition :: list
 + another :: def
 EOF

 # walk the document tree
 $doc->walk(sub {
     my ($el) = @_;
     return unless $el->isa('Org::Element::Headline');
     say "heading level ", $el->level, ": ", $el->title->as_string;
 });

will print something like:

 heading level 1: heading1a
 heading level 2: heading2a
 heading level 2: heading2b *bold*
 heading level 1: heading1b
 heading level 1: heading1c

A command-line utility (in a separate distribution: L<App::OrgUtils>) is
available for debugging:

 % dump-org-structure ~/todo.org
 Document:
   Setting: "#+TODO: TODO | DONE CANCELLED\n"
   RadioTarget: "<<<radio target>>>"
   Text: "\n"
   Headline: l=1
     (title)
     Text: "heading1a"
     (children)
     Headline: l=2 todo=TODO
       (title)
       Text: "heading2a"
       (children)
       Text: "SCHEDULED: "
 ...


=head1 DESCRIPTION

This module parses Org documents. See http://orgmode.org/ for more details on
Org documents.

See C<todo.org> in the distribution for the list of already- and not yet
implemented stuffs.


=head1 ATTRIBUTES


=head1 METHODS

=head2 new()

Create a new parser instance.

=head2 $orgp->parse($str | $arrayref | $coderef | $filehandle, \%opts) => $doc

Parse document (which can be contained in a scalar $str, an arrayref of lines
$arrayref, a subroutine which will be called for chunks until it returns undef,
or a filehandle).

Returns L<Org::Document> object.

If 'handler' attribute is specified, will call handler repeatedly during
parsing. See the 'handler' attribute for more details.

Will die if there are syntax errors in documents.

Known options:

=over 4

=item * time_zone => STR

Will be passed to Org::Document's constructor.

=back

=head2 $orgp->parse_file($filename, \%opts) => $doc

Just like parse(), but will load document from file instead.

Known options (aside from those known by parse()):

=over 4

=item * cache => bool (default: from PERL_ORG_PARSER_CACHE, or 0)

Since Org::Parser can spend some time to parse largish Org files, this is an
option to store the parse result (using L<Storable>). If caching is turned on,
then after the first parse, the result will be stored in:

 ~/.cache/perl-org-parser/<filename>.<md5-digest-of-file-absolute-path>.storable

and subsequent calls to this function can directly use this cache, as long as
the cache is not stale.

=back

=head1 FAQ

=head2 Why? Just as only perl can parse Perl, only org-mode can parse Org anyway!

True. I'm only targetting good enough. As long as I can parse/process all my Org
notes and todo files, I have no complaints.

=head2 It's too slow!

Parser is completely regex-based at the moment (I plan to use L<Marpa> someday).
Performance is quite lousy but I'm not annoyed enough at the moment to overhaul
it.


=head1 ENVIRONMENT

=head2 PERL_ORG_PARSER_CACHE => bool

Set default for C<cache> option in C<parse_file()>.


=head1 SEE ALSO

L<Org::Document>
