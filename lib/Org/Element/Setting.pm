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

=head2 raw_arg => STR

Raw argument of setting.

=cut

has raw_arg => (is => 'rw');

=head2 args => HASH

Parsed argument.

=cut

has args => (is => 'rw');


=head1 METHODS

=for Pod::Coverage element_as_string BUILD

=cut

sub BUILD {
    require Org::Document;
    my ($self, $args) = @_;

    my $name    = uc $self->name;
    $self->name($name);
    my $raw_arg = $self->raw_arg;
    unless (defined $self->args) {
        my $args = {};
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
            my $d = [split /\s+/, $raw_arg];
            $args->{drawers} = $d;
            for (@$d) {
                push @{ $doc->drawers }, $_
                    unless $_ ~~ @{ $doc->drawers };
            }
        } elsif ($name eq 'EMAIL') {
        } elsif ($name eq 'EXPORT_EXCLUDE_TAGS') {
        } elsif ($name eq 'EXPORT_SELECT_TAGS') {
        } elsif ($name eq 'FILETAGS') {
            $raw_arg =~ /^$Org::Document::tags_re$/ or
                die "Invalid argument syntax for FILEARGS: $raw";
            $args->{tags} = Org::Document::__split_tags($raw_arg);
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
        } elsif ($name eq 'PRIORITIES') {
            my $p = [split /\s+/, $raw_arg];
            $args->{priorities} = $p;
            $doc->priorities($p);
        } elsif ($name eq 'PROPERTY') {
            $raw_arg =~ /(\w+)\s+($Org::Document::arg_val_re)$/
                or die "Invalid argument for PROPERTY setting, ".
                    "please use 'NAME VALUE': $raw_arg";
            $args->{name} = $1;
            $args->{value} = Org::Document::__get_arg_val($2);
        } elsif ($name =~ /^(SEQ_TODO|TODO|TYP_TODO)$/) {
            my $done;
            my @args = split /\s+/, $raw_arg;
            $args->{states} = \@args;
            for (my $i=0; $i<@args; $i++) {
                my $arg = $args[$i];
                if ($arg eq '|') { $done++; next }
                $done++ if !$done && @args > 1 && $i == @args-1;
                my $ary = $done ? $doc->done_states : $doc->todo_states;
                push @$ary, $arg unless $arg ~~ @$ary;
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
            die "Unknown setting $name: $raw";
        }
        $self->args($args);
    }
}

sub element_as_string {
    my ($self) = @_;
    join("",
         "#+".uc($self->name),
         defined($self->raw_arg) ? " ".$self->raw_arg : "",
         "\n");
}

1;
__END__

=head1 DESCRIPTION

Derived from Org::Element::Base.

=cut
