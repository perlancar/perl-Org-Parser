package Org::Element::Text;
# ABSTRACT: Represent text

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 text_style

undef/''=normal, I=italic, B=bold, U=underline, S=strikethrough, V=verbatim,
C=code

=cut

has text => (is => 'rw');

has style => (is => 'rw');


=head1 METHODS

=for Pod::Coverage element_as_string BUILD

=head2 new(raw => STR, document => OBJ)

Create a new headline item from parsing raw string. (You can also create
directly by filling out priority, title, etc).

=cut

sub BUILD {
    my ($self, $args) = @_;
    my $raw = $args->{raw};
    if (defined $raw) {
        my $doc = $self->document
            or die "Please specify document when specifying raw";
        state $re = qr!\A
                       ([*_=/~+]?) (.*) \1
                       \z!sx;
        $raw =~ $re;
        $self->text($2);
        $self->style(
            !$1 ? undef :
                $1 eq '*' ? 'B' :
                    $1 eq '_' ? 'U' :
                        $1 eq '=' ? 'C' :
                            $1 eq '/' ? 'I' :
                                $1 eq '~' ? 'V' :
                                    $1 eq '+' ? 'S' : '?');
    }
}

sub element_as_string {
    my ($self) = @_;
    return $self->_raw if defined($self->_raw);
    my $text  = $self->text;
    my $style = $self->style;
    if (!$style) {
        return $text;
    } elsif ($style eq 'B') {
        return "*$text*";
    } elsif ($style eq 'I') {
        return "/$text/";
    } elsif ($style eq 'U') {
        return "_${text}_";
    } elsif ($style eq 'V') {
        return "~$text~";
    } elsif ($style eq 'C') {
        return "=$text=";
    } elsif ($style eq 'S') {
        return "+$text+";
    } else {
        die "Unknown style $style";
    }
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
