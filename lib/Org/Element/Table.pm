package Org::Element::Table;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010;
use locale;
use Log::ger;
use Moo;
extends 'Org::Element';
with 'Org::Element::Role';
with 'Org::Element::BlockRole';

has _dummy => (is => 'rw'); # workaround Moo bug

sub BUILD {
    require Org::Element::TableRow;
    require Org::Element::TableHLine;
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
            log_trace("table line: %s", $row0);
            next unless $row0 =~ /\S/;
            my $row;
            if ($row0 =~ /^\s*\|--+(?:\+--+)*\|?\s*$/) {
                $row = Org::Element::TableHLine->new(parent => $self);
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

sub rows {
    my ($self) = @_;
    return [] unless $self->children;
    my $rows = [];
    for my $el (@{$self->children}) {
        push @$rows, $el if $el->isa('Org::Element::TableRow');
    }
    $rows;
}

sub row_count {
    my ($self) = @_;
    return 0 unless $self->children;
    my $n = 0;
    for my $el (@{$self->children}) {
        $n++ if $el->isa('Org::Element::TableRow');
    }
    $n;
}

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

sub as_aoa {
    my ($self) = @_;
    return [] unless $self->children;

    my @rows;
    for my $row (@{$self->children}) {
        next unless $row->isa('Org::Element::TableRow');
        push @rows, $row->as_array;
    }
    \@rows;
}

1;
# ABSTRACT: Represent Org table

=for Pod::Coverage BUILD

=head1 DESCRIPTION

Derived from L<Org::Element>. Must have L<Org::Element::TableRow> or
L<Org::Element::TableHLine> instances as its children.


=head1 ATTRIBUTES


=head1 METHODS

=head2 $table->rows() => ELEMENTS

Return the rows of the table.

=head2 $table->as_aoa() => ARRAY

Return the rows of the table, each row already an arrayref of cells produced
using as_array() method. Horizontal lines will be skipped/ignored.

=head2 $table->row_count() => INT

Return the number of rows that the table has.

=head2 $table->column_count() => INT

Return the number of columns that the table has. It is counted from the first
row.

=cut
