package Org::Element::Timestamp;

use 5.010;
use locale;
use utf8;
use Moo;
no if $] >= 5.021_006, warnings => "locale";
extends 'Org::Element';
with 'Org::ElementRole';
with 'Org::ElementRole::Inline';

# AUTHORITY
# DATE
# DIST
# VERSION

my @attrs = (qw/datetime has_time event_duration recurrence is_active/);
for (@attrs) {
    has $_ => (is => 'rw', clearer=>"clear_$_");
    before $_ => sub {
        my $self = shift;
        return unless defined $self->_is_parsed; # never been parsed
        $self->_parse_timestamp($self->_str)
            unless $self->_is_parsed; # has been reset, re-set
    };
}

has _repeater => (is => 'rw'); # stores the raw repeater spec, for as_string
has _warning_period => (is => 'rw'); # raw warning period spec, for as_string
has _is_parsed => (is => 'rw');

sub clear_parse_result {
    my $self = shift;
    return unless defined $self->_is_parsed; # never been parsed
    for (@attrs) { my $m = "clear_$_"; $self->$m }
    $self->_is_parsed(0);
}

our @dow = (undef, qw(Mon Tue Wed Thu Fri Sat Sun));

sub as_string {
    my ($self) = @_;
    return $self->_str if $self->_str;
    my $dt = $self->datetime;
    my ($hour2, $min2);
    if ($self->event_duration) {
        my $hour = $dt->hour;
        my $min = $dt->minute;
        my $mins = $self->event_duration / 60;
        $min2 = $min + $mins;
        my $hours = int ($min2 / 60);
        $hour2 = $hour + $hours;
        $min2  = $min2 % 60;
    }
    join("",
         $self->is_active ? "<" : "[",
         $dt->ymd, " ",
         $dow[$dt->day_of_week],
         $self->has_time ? (
             " ",
             sprintf("%02d:%02d", $dt->hour, $dt->minute),
             defined($hour2) ? (
                 "-",
                 sprintf("%02d:%02d", $hour2, $min2),
             ) : (),
             $self->_repeater ? (
                 " ",
                 $self->_repeater,
             ) : (),
             $self->_warning_period ? (
                 " ",
                 $self->_warning_period,
             ) : (),
         ) : (),
         $self->is_active ? ">" : "]",
     );
}

sub as_text {
    goto \&as_string;
}

sub _parse_timestamp {
    require DateTime;
    require DateTime::Event::Recurrence;
    my ($self, $str, $opts) = @_;
    $self->_is_parsed(undef); # to avoid deep recursion
    $opts //= {};
    $opts->{allow_event_duration} //= 1;
    $opts->{allow_repeater} //= 1;

    my $num_re = qr/\d+(?:\.\d+)?/;

    my $dow_re = qr/\w{1,3} |     # common, chinese 四, english thu
                    \w{2,3}\.     # french mer., german Mi.
                   /x;

    $str =~ /^(?<open_bracket> \[|<)
             (?<year> \d{4})-(?<mon> \d{2})-(?<day> \d{2})
             (?:
                 (?:\s* (?<dow> $dow_re) \s*)?
                 (?:\s+
                     (?<hour> \d{2}):(?<min> \d{2})
                     (?:-
                         (?<event_duration>
                             (?<hour2> \d{2}):(?<min2> \d{2}))
                     )?
                 )?
                 (?:\s+(?<repeater>
                         (?<repeater_prefix> \+\+|\.\+|\+)
                         (?<repeater_interval> $num_re)
                         (?<repeater_unit> [dwmy])
                         (?:\/(?<repeater_interval_max> $num_re)
                             (?<repeater_unit_max> [dwmy]))?
                     )
                 )?
                 (?:\s+(?<warning_period>
                         -
                         (?<warning_period_interval> $num_re)
                         (?<warning_period_unit> [dwmy])
                     )
                 )?
             )?
             \s* (?<close_bracket> \]|>)
             $/x
                 or die "Can't parse timestamp string: $str";
    # just for sanity. usually doesn't happen though because Document gives us
    # either "[...]" or "<...>"
    die "Mismatch open/close brackets in timestamp: $str"
        if $+{open_bracket} eq '<' && $+{close_bracket} eq ']' ||
            $+{open_bracket} eq '[' && $+{close_bracket} eq '>';
    die "Duration not allowed in timestamp: $str"
        if !$opts->{allow_event_duration} && $+{event_duration};
    die "Repeater ($+{repeater}) not allowed in timestamp: $str"
        if !$opts->{allow_repeater} && $+{repeater};

    $self->is_active($+{open_bracket} eq '<' ? 1:0)
        unless defined $self->is_active;

    if ($+{event_duration} && !defined($self->event_duration)) {
        $self->event_duration(
            ($+{hour2}-$+{hour})*3600 +
            ($+{min2} -$+{min} )*60
        );
    }

    my %dt_args = (year => $+{year}, month=>$+{mon}, day=>$+{day});
    if (defined($+{hour})) {
        $dt_args{hour}   = $+{hour};
        $dt_args{minute} = $+{min};
        $self->has_time(1);
    } else {
        $self->has_time(0);
    }
    if ($self->document->time_zone) {
        $dt_args{time_zone} = $self->document->time_zone;
    }
    #use Data::Dump; dd \%dt_args;
    my $dt = DateTime->new(%dt_args);

    if ($+{repeater} && !$self->recurrence) {
        my $r;
        my $i = $+{repeater_interval};
        my $u = $+{repeater_unit};
        if ($u eq 'd') {
            $r = DateTime::Event::Recurrence->daily(
                interval=>$i, start=>$dt);
        } elsif ($u eq 'w') {
            $r = DateTime::Event::Recurrence->weekly(
                interval=>$i, start=>$dt);
        } elsif ($u eq 'm') {
            $r = DateTime::Event::Recurrence->monthly(
                interval=>$i, start=>$dt);
        } elsif ($u eq 'y') {
            $r = DateTime::Event::Recurrence->yearly(
                interval=>$i, start=>$dt);
        } else {
            die "BUG: Unknown repeater unit $u in timestamp $str";
        }
        $self->recurrence($r);
        $self->_repeater($+{repeater});
    }

    if ($+{warning_period}) {
        my $i = $+{warning_period_interval};
        my $u = $+{warning_period_unit};
        if ($u eq 'd') {
        } elsif ($u eq 'w') {
        } elsif ($u eq 'm') {
        } elsif ($u eq 'y') {
        } else {
            die "BUG: Unknown warning period unit $u in timestamp $str";
        }
        $self->_warning_period($+{warning_period});
    }

    $self->_is_parsed(1);
    $self->datetime($dt);
}

1;
# ABSTRACT: Represent Org timestamp

=head1 DESCRIPTION

Derived from L<Org::Element>.

Supported formats:

=over

=item * C<[...]> and C<< <...> >> (active) forms

=item * basic date: C<[2013-10-27 Sun]>

=item * event duration: C<[2011-03-23 Wed 10:12-11:23]>

=item * repeater: C<[2011-03-23 Wed +3m]> including C<++> and C<.+>

=item * habit-style repeater: C<[2011-03-23 Wed 10:12 +1d/2d]>

=item * warning period: C<< <2011-05-25 Wed +17.1m -13.2d> >>

=back


=head1 ATTRIBUTES

=head2 datetime => DATETIME_OBJ

=head2 has_time => BOOL

=head2 event_duration => INT

Event duration in seconds, e.g. for event timestamp like this:

 <2011-03-23 10:15-13:25>

event_duration is 7200+600=7800 (2 hours 10 minutes).

=head2 recurrence => DateTime::Event::Recurrence object

=head2 is_active => BOOL


=head1 METHODS

=head2 $el->clear_parse_result

Clear parse result.

Since the DateTime::Set::ICal (recurrence) object contains coderefs (and thus
poses problem to serialization), an option is provided to remove parse result.
You can do this prior to serializing the object.

Timestamp will automatically be parsed again from _str when one of the
attributes is accessed.

=head2 as_string => str

From L<Org::Element>.

=head2 as_text => str

From L<Org::ElementRole::Inline>.


=head1 BUGS AND LIMITATIONS

=over

=item * Habit-style repeater (e.g. 2d/3d) is not yet represented in C<recurrence>

The recurrence object currently will still only include 2d (without the maximum
interval).

=back

=cut
