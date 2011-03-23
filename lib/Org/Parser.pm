package Org::Parser;
# ABSTRACT: Parse Org documents

use 5.010;
use Moo;

use File::Slurp;
use Org::Document;
use Scalar::Util qw(blessed);

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
    Org::Document->new(from_string=>$str);
}

sub parse_file {
    my ($self, $filename) = @_;
    $self->parse(scalar read_file($filename));
}

1;
__END__

=head1 SYNOPSIS

 use 5.010;
 use Org::Parser;
 my $orgp = Org::Parser->new();

 # parse a file
 my $doc = $orgp->parse_file("$ENV{HOME}/todo.org");

 # parse a string
 $doc = $orgp->parse(<<EOF);
 * heading1a
 ** TODO heading2a
 ** DONE heading2b
 * TODO heading1b
 * heading1c
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
 heading level 2: heading2b
 heading level 1: heading1b
 heading level 1: heading1c


=head1 DESCRIPTION

This module parses Org documents. See http://orgmode.org/ for more details on
Org documents.

This module uses L<Log::Any> logging framework.

This module uses L<Moo> object system.

See C<todo.org> in the distribution for the list of already- and not yet
implemented stuffs,


=head1 ATTRIBUTES

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


=head1 SEE ALSO

Org::Document

=cut

1;
