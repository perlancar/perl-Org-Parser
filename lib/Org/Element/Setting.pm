package Org::Element::Setting;
# ABSTRACT: Represent Org in-buffer settings

use 5.010;
use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 name => STR

Setting name.

=cut

has name => (is => 'rw');

=head2 args => ARRAY

Setting's arguments.

=cut

has args => (is => 'rw');


=head1 METHODS

=for Pod::Coverage element_as_string BUILD

=cut

sub BUILD {
    require Org::Document;
    my ($self, $build_args) = @_;
    my $doc = $self->document;
    my $pass = $build_args->{pass} // 1;

    my $name    = uc $self->name;
    $self->name($name);

    my $args = $self->args;
    if      ($name eq 'ARCHIVE') {
    } elsif ($name eq 'AUTHOR') {
    } elsif ($name eq 'BABEL') {
    } elsif ($name eq 'CALL') {
    } elsif ($name eq 'CAPTION') {
    } elsif ($name eq 'BIND') {
    } elsif ($name eq 'CATEGORY') {
    } elsif ($name eq 'COLUMNS') {
    } elsif ($name eq 'CONSTANTS') {
    } elsif ($name eq 'DATE') {
    } elsif ($name eq 'DESCRIPTION') {
    } elsif ($name eq 'DRAWERS') {
        if ($pass == 1) {
            for (@$args) {
                push @{ $doc->drawers }, $_
                    unless $_ ~~ @{ $doc->drawers };
            }
        }
    } elsif ($name eq 'EMAIL') {
    } elsif ($name eq 'EXPORT_EXCLUDE_TAGS') {
    } elsif ($name eq 'EXPORT_SELECT_TAGS') {
    } elsif ($name eq 'FILETAGS') {
        if ($pass == 1) {
            $args->[0] =~ /^$Org::Document::tags_re$/ or
                die "Invalid argument for FILETAGS: $args->[0]";
            for (@{ $args->[0] }) {
                push @{ $doc->tags }, $_
                    unless $_ ~~ @{ $doc->tags };
            }
        }
    } elsif ($name eq 'INCLUDE') {
    } elsif ($name eq 'INDEX') {
    } elsif ($name eq 'KEYWORDS') {
    } elsif ($name eq 'LABEL') {
    } elsif ($name eq 'LANGUAGE') {
    } elsif ($name eq 'LATEX_HEADER') {
    } elsif ($name eq 'LINK') {
    } elsif ($name eq 'LINK_HOME') {
    } elsif ($name eq 'LINK_UP') {
    } elsif ($name eq 'OPTIONS') {
    } elsif ($name eq 'PLOT') {
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
    } elsif ($name eq 'SETUPFILE') {
    } elsif ($name eq 'STARTUP') {
    } elsif ($name eq 'STYLE') {
    } elsif ($name eq 'TAGS') {
    } elsif ($name eq 'TBLFM') {
    } elsif ($name eq 'TEXT') {
    } elsif ($name eq 'TITLE') {
    } elsif ($name eq 'XSLT') {
    } else {
        die "Unknown setting $name";
    }
}

sub as_string {
    my ($self) = @_;
    join("",
         "#+".uc($self->name),
         $self->args && @{$self->args} ?
             " ".Org::Document::__format_args($self->args) : "",
         "\n"
     );
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
