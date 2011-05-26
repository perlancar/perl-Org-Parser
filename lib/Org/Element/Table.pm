package Org::Element::Table;
# ABSTRACT: Represent Org table

use 5.010;
use locale;
use Log::Any '$log';
use Moo;
extends 'Org::Element::Base';

=head1 DESCRIPTION

Must have L<Org::Element::TableRow> or L<Org::Element::TableVLine> instances as
its children.


=head1 ATTRIBUTES

=cut

has _dummy => (is => 'rw'); # workaround Moo bug


=head1 METHODS

=for Pod::Coverage BUILD

=cut

sub BUILD {
    require Org::Element::TableRow;
    require Org::Element::TableVLine;
    require Org::Element::TableCell;
    my ($self, $args) = @_;
    my $pass = $args->{pass} // 1;

    # parse _str into rows & cells
    my $_str = $args->{_str};
    if (defined $_str && !defined($self->children)) {

        if (!defined($self->_str_include_children)) {
            $self->_str_include_children(1);
        }

        my $doc = $self->document;
        my @rows0 = split /\R/, $_str;
        $self->children([]);
        for my $row0 (@rows0) {
            $log->tracef("table line: %s", $row0);
            next unless $row0 =~ /\S/;
            my $row;
            if ($row0 =~ /^\s*\|--+(?:\+--+)*\|?\s*$/) {
                $row = Org::Element::TableVLine->new(parent => $self);
            } elsif ($row0 =~ /^\s*\|\s*(.+?)\s*\|?\s*$/) {
                my $s = $1;
                $row = Org::Element::TableRow->new(
                    parent => $self, children=>[]);
                for my $cell0 (split /\s*\|\s*/, $s) {
                    my $cell = Org::Element::TableCell->new(
                        parent => $row, children=>[]);
                    $doc->_add_text($cell0, $cell, $pass);
                    push @{ $row->children }, $cell;
                }
            } else {
                die "Invalid line in table: $row0";
            }
            push @{$self->children}, $row;
        }
    }
}

=head2 $table->row_count() => INT

Return the number of rows that the table has.

=cut

sub row_count {
    my ($self) = @_;
    return 0 unless $self->children;
    my $n = 0;
    for my $el (@{$self->children}) {
        $n++ if $el->isa('Org::Element::TableRow');
    }
    $n;
}

=head2 $table->column_count() => INT

Return the number of columns that the table has. It is counted from the first
row.

=cut

sub column_count {
    my ($self) = @_;
    return 0 unless $self->children;

    # get first row
    my $row;
    for my $el (@{$self->children}) {
        if ($el->isa('Org::Element::TableRow')) {
            $row = $el;
            last;
        }
    }
    return 0 unless $row; # table doesn't have any row

    my $n = 0;
    for my $el (@{$row->children}) {
        $n++ if $el->isa('Org::Element::TableCell');
    }
    $n;
}

1;
__END__

=head1 DESCRIPTION

Derived from L<Org::Element::Base>.

=cut
