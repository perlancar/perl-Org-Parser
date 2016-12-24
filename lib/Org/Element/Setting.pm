package Org::Element::Setting;

# DATE
# VERSION

use 5.010001;
use locale;
use Moo;
use experimental 'smartmatch';
extends 'Org::Element';
with 'Org::Element::Role';
with 'Org::Element::BlockRole';

our @known_settings = qw(
ARCHIVE
ASCII
ATTR_ASCII
ATTR_BEAMER
ATTR_HTML
ATTR_LATEX
ATTR_ODT
AUTHOR
BABEL
BEAMER
BEAMER_COLOR_THEME
BEAMER_FONT_THEME
BEAMER_INNER_THEME
BEAMER_OUTER_THEME
BEAMER_THEME
BEGIN
BEGIN_ASCII
BEGIN_BEAMER
BEGIN_CENTER
BEGIN_COMMENT
BEGIN_EXAMPLE
BEGIN_HTML
BEGIN_LATEX
BEGIN_QUOTE
BEGIN_SRC
BEGIN_SRC
BEGIN_VERSE
BIND
CALL
CAPTION
CATEGORY
COLUMNS
CONSTANTS
DATE
DESCRIPTION
DRAWERS
EMAIL
EXPORT_EXCLUDE_TAGS
EXPORT_INCLUDE_TAGS
FILETAGS
HEADER
HEADERS
HTML
HTML_HEAD
HTML_HEAD_EXTRA
HTML_INCLUDE_STYLE
INCLUDE
INDEX
INFOJS_OPT
KEYWORDS
LABEL
LANGUAGE
LAST_MOBILE_CHANGE
LATEX
LATEX_CLASS
LATEX_CLASS_OPTIONS
LATEX_HEADER
LATEX_HEADER_EXTRA
LINK
LINK_HOME
LINK_UP
MACRO
NAME
ODT_STYLES_FILE
OPTIONS
ORGLST
ORGTBL
PLOT
POSTID
PRIORITIES
PROPERTY
RESULTS
SEQ_TODO
SETUPFILE
SRCNAME
STARTUP
STYLE
TAGS
TBLFM
TEXT
TITLE
TOC
TODO
TYP_TODO
XSLT
                    );

has name => (is => 'rw');
has args => (is => 'rw');
has indent => (is => 'rw');

# static method
sub indentable_settings {
    state $data = [qw/TBLFM/];
    $data;
}

sub BUILD {
    require Org::Document;
    my ($self, $build_args) = @_;
    my $doc = $self->document;
    my $pass = $build_args->{pass} // 1;

    my $name    = uc $self->name;
    $self->name($name);

    my $args = $self->args;
    if ($name eq 'DRAWERS') {
        if ($pass == 1) {
            for (@$args) {
                push @{ $doc->drawer_names }, $_
                    unless $_ ~~ @{ $doc->drawer_names };
            }
        }
    } elsif ($name eq 'FILETAGS') {
        if ($pass == 1) {
            $args->[0] =~ /^$Org::Document::tags_re$/ or
                die "Invalid argument for FILETAGS: $args->[0]";
            for (split /:/, $args->[0]) {
                next unless length;
                push @{ $doc->tags }, $_
                    unless $_ ~~ @{ $doc->tags };
            }
        }
    } elsif ($name eq 'PRIORITIES') {
        if ($pass == 1) {
            for (@$args) {
                push @{ $doc->priorities }, $_;
            }
        }
    } elsif ($name eq 'PROPERTY') {
        if ($pass == 1) {
            @$args >= 2 or die "Not enough argument for PROPERTY, minimum 2";
            my $name = shift @$args;
            $doc->properties->{$name} = @$args > 1 ? [@$args] : $args->[0];
        }
    } elsif ($name =~ /^(SEQ_TODO|TODO|TYP_TODO)$/) {
        if ($pass == 1) {
            my $done;
            for (my $i=0; $i<@$args; $i++) {
                my $arg = $args->[$i];
                if ($arg eq '|') { $done++; next }
                $done++ if !$done && @$args > 1 && $i == @$args-1;
                my $ary = $done ? $doc->done_states : $doc->todo_states;
                push @$ary, $arg unless $arg ~~ @$ary;
            }
        }
    } else {
        unless ($self->document->ignore_unknown_settings) {
            die "Unknown setting $name" unless $name ~~ @known_settings;
        }
    }
}

sub as_string {
    my ($self) = @_;
    join("",
         $self->indent // "",
         "#+".uc($self->name), ":",
         $self->args && @{$self->args} ?
             " ".Org::Document::__format_args($self->args) : "",
         "\n"
     );
}

1;
# ABSTRACT: Represent Org in-buffer settings

=for Pod::Coverage as_string BUILD

=head1 DESCRIPTION

Derived from L<Org::Element>.


=head1 ATTRIBUTES

=head2 name => STR

Setting name.

=head2 args => ARRAY

Setting's arguments.

=head2 indent => STR

Indentation (whitespaces before C<#+>), or empty string if none.


=head1 METHODS

=head2 Org::Element::Setting->indentable_settings -> ARRAY

Return an arrayref containing the setting names that can be indented. In Org,
some settings can be indented and some can't. Setting names are all in
uppercase.

=cut
