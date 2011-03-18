package Org::Document;
# ABSTRACT: Represent an Org document

use 5.010;
use strict;
use warnings;

use Moo;
extends 'Org::Element::Base';

=head1 ATTRIBUTES

=head2 todo_states => ARRAY

List of known (action-requiring) todo states. Default is ['TODO'].

=cut

has todo_states             => (is => 'rw', default => sub{[qw/TODO/]});

=head2 done_states => ARRAY

List of known done (non-action-requiring) states. Default is ['DONE'].

=cut

has done_states             => (is => 'rw', default => sub{[qw/DONE/]});

=head2 priorities => ARRAY

List of known priorities. Default is ['A', 'B', 'C'].

=cut

has priorities              => (is => 'rw', default => sub{[qw/A B C/]});

=head2 drawers => ARRAY

List of known drawer names. Default is [qw/CLOCK LOGBOOK PROPERTIES/].

=cut

has drawers                 => (is => 'rw', default => sub{[
    qw/CLOCK LOGBOOK PROPERTIES/]});

has _parser => (is => 'rw');

1;
__END__

=head1 DESCRIPTION

Normally you would use L<Org::Parser> to create this object from an existing Org
documents.

Derived from Org::Element::Base.

=cut
