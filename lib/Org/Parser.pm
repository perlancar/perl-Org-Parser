package Org::Parser;
# ABSTRACT: Parse Org documents

use 5.010;
use Moo;

use File::Slurp;
use Org::Document;
use Scalar::Util qw(blessed);

has handler => (is => 'rw');

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
    Org::Document->new(from_string=>$str, _handler=>$self->handler);
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

See C<todo.org> in the distribution for the list of already- and not yet
implemented stuffs,


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


=head1 SEE ALSO

=cut

1;
