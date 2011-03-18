package Calendar::Saka;

use strict; use warnings;

=head1 NAME

Calendar::Saka - Interface to Saka Calendar (Indian).

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

use Carp;
use Readonly;
use Data::Dumper;
use POSIX qw/floor/;
use Time::localtime;
use List::Util qw/min/;
use Date::Calc qw/Delta_Days Day_of_Week Add_Delta_Days/;

Readonly my $MONTHS =>
[
    'Chaitra', 'Vaisakha', 'Jyaistha',   'Asadha', 'Sravana', 'Bhadra',
    'Asvina',  'Kartika',  'Agrahayana', 'Pausa',  'Magha',   'Phalguna'
];

Readonly my $DAYS => 
[
    'Ravivara',       'Somvara',   'Mangalavara', 'Budhavara',
    'Brahaspativara', 'Sukravara', 'Sanivara'    
];

# Day offset between Saka and Gregorian.
Readonly my $START => 80;

# Offset in years from Saka era to Gregorian epoch.
Readonly my $SAKA => 78;

Readonly my $GREGORIAN_EPOCH => 1721425.5;

sub new 
{
    my $class = shift;
    my $yyyy  = shift;
    my $mm    = shift;
    my $dd    = shift;
    
    my $self  = {};
    bless $self, $class;
    
    if (defined($yyyy) && defined($mm) && defined($dd))
    {
        _validate_date($yyyy, $mm, $dd)
    }
    else
    {
        my $today = localtime; 
        $yyyy = ($today->year+1900) unless defined $yyyy;
        $mm = ($today->mon+1) unless defined $mm;
        $dd = $today->mday unless defined $dd;    
        ($yyyy, $mm, $dd) = $self->from_gregorian($yyyy, $mm, $dd);
    }

    $self->{yyyy} = $yyyy;
    $self->{mm}   = $mm;
    $self->{dd}   = $dd;

    return $self;
}

=head1 SYNOPSIS

Module to play with Saka calendar mostly used in the South indian, Goa and Maharashatra. It supports the
functionality  to  add / minus days, months  and years to a Saka date. It can also converts Saka date to
 Gregorian/Julian date.

The  Saka  eras  are  lunisolar  calendars, and feature annual cycles of twelve lunar months, each month
divided  into  two  phases:  the  'bright half' (shukla) and the 'dark half' (krishna); these correspond
respectively  to  the  periods  of the 'waxing' and the 'waning' of the moon. Thus, the period beginning
from  the  first  day  after  the new moon and ending on the full moon day constitutes the shukla paksha
or 'bright half' of the month; the period beginning from the day after the full moon until and including
the next new moon day constitutes the krishna paksha or 'dark half' of the month.

The  "year zero"  for the two calendars is different. In the Vikrama calendar, the zero year corresponds
to 58 BCE, while in the Shalivahana calendar, it corresponds to 78 CE. The Saka calendar begins with the
month of Chaitra (March) and the Ugadi/Gudi Padwa festivals mark the new year. 

Each month in the Shalivahana calendar begins with the 'bright half' and is followed by the 'dark half'.
Thus,  each  month of the Shalivahana calendar ends with the no-moon day and the new month begins on the
day after that.

A variant  of  the  Saka Calendar was reformed and standardized as the Indian National calendar in 1957.
This official calendar follows the Shalivahan Shak calendar in beginning from  the  month of Chaitra and
counting  years  with  78 CE being year zero. It features a constant number of days in every month (with
leap years).

            Phalguna [1932]

    Sun  Mon  Tue  Wed  Thu  Fri  Sat
      1    2    3    4    5    6    7
      8    9   10   11   12   13   14
     15   16   17   18   19   20   21
     22   23   24   25   26   27   28
     29   30

=head1 METHODS

=head2 as_string()

Return Saka date in human readable format.

    use strict; use warnings;
    use Calendar::Saka;
    
    my $saka = Calendar::Saka->new(1932,12,26);
    print "Saka date is " . $saka->as_string() . "\n";

=cut

sub as_string
{
    my $self = shift;
    return sprintf("%02d, %s %04d", $self->{dd}, $MONTHS->[$self->{mm}-1], $self->{yyyy});
}

=head2 today()

Return today's date is Sake calendar as list in the format yyyy,mm,dd.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new();
    my ($yyyy, $mm, $dd) = $saka->today();
    print "Year [$yyyy] Month [$mm] Day [$dd]\n";

=cut

sub today
{
    my $self  = shift;
    my $today = localtime; 
    return $self->from_gregorian($today->year+1900, $today->mon+1, $today->mday);
}

=head2 mon(mm)

Return name of the given month according to the Saka Calendar.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new();
    print "Month name: [" . $saka->mon() . "]\n";

=cut

sub mon
{
    my $self = shift;
    my $mm   = shift;
    $mm = $self->{mm} unless defined $mm;
    
    _validate_date(2000, $mm, 1);
    
    return $MONTHS->[$mm-1];
}

=head2 dow(yyyy, mm, dd)

Get day of the week of the given Saka date, starting with sunday (0).

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new();
    print "Day of the week; [" . $saka->dow() . "]\n";

=cut

sub dow
{
    my $self = shift;
    my $yyyy = shift;
    my $mm   = shift;
    my $dd   = shift;

    $yyyy = $self->{yyyy} unless defined $yyyy;
    $mm   = $self->{mm}   unless defined $mm;
    $dd   = $self->{dd}   unless defined $dd;

    _validate_date($yyyy, $mm, $dd);

    my @gregorian = $self->to_gregorian($yyyy, $mm, $dd);
    return Day_of_Week(@gregorian);
}

=head2 days_in_year_month(yyyy, mm)

Return number of days in the given year and month of Saka calendar.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new(1932,12,26);
    print "Days is Phalguna 1932: [" . $saka->days_in_year_month() . "]\n";

    print "Days is Chaitra 1932: [" . $saka->days_in_year_month(1932,1) . "]\n";

=cut

sub days_in_year_month
{
    my $self = shift;
    my $yyyy = shift;
    my $mm   = shift;

    $yyyy = $self->{yyyy} unless defined $yyyy;
    $mm   = $self->{mm}   unless defined $mm;

    _validate_date($yyyy, $mm, 1);

    my (@start, @end);
    @start = $self->to_gregorian($yyyy, $mm, 1);
    if ($mm == 12)
    {
        $yyyy += 1;
        $mm    = 1;
    }
    else
    {
        $mm += 1;
    }
    @end = $self->to_gregorian($yyyy, $mm, 1);

    return Delta_Days(@start, @end);
}

=head2 add_days(no_of_days)

Add no_of_days to the Sake date.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new(1932,12,5);
    print "Saka 1:" . $saka->as_string() . "\n";
    $saka->add_days(5);
    print "Saka 2:" . $saka->as_string() . "\n";

=cut

sub add_days
{
    my $self = shift;
    my $no_of_days = shift;
    croak("ERROR: Invalid day count.\n")
        unless ($no_of_days =~ /^\-?\d+$/);

    my ($yyyy, $mm, $dd) = $self->to_gregorian();
    ($yyyy, $mm, $dd) = Add_Delta_Days($yyyy, $mm, $dd, $no_of_days);
    ($yyyy, $mm, $dd) = $self->from_gregorian($yyyy, $mm, $dd);
    $self->{yyyy} = $yyyy;
    $self->{mm}   = $mm;
    $self->{dd}   = $dd;

    return;
}

=head2 minus_days(no_of_days)

Minus no_of_days from the Sake date.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new(1932,12,5);
    print "Saka 1:" . $saka->as_string() . "\n";
    $saka->minus_days(2);
    print "Saka 2:" . $saka->as_string() . "\n";

=cut

sub minus_days
{
    my $self = shift;
    my $no_of_days = shift;
    croak("ERROR: Invalid day count.\n")
        unless ($no_of_days =~ /^\d+$/);

    return $self->add_days(-1 * $no_of_days);
}

=head2 add_months(no_of_months)

Add no_of_months to the Saka date.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new(1932,1,1);
    print "Saka 1:" . $saka->as_string() . "\n";
    $saka->add_months(2);
    print "Saka 2:" . $saka->as_string() . "\n";

=cut

sub add_months
{
    my $self = shift;
    my $no_of_months = shift;
    croak("ERROR: Invalid month count.\n")
        unless ($no_of_months =~ /^\d+$/);

    if (($self->{mm}+$no_of_months) > 12)
    {
        while (($self->{mm} + $no_of_months) > 12)
        {
            my $_mm = 12 - $self->{mm};
            $self->{yyyy}++;
            $self->{mm} = 1;
            $no_of_months = $no_of_months - ($_mm + 1);
        }
    }
    $self->{mm} += $no_of_months;

    return;
}

=head2 minus_months(no_of_months)

Mnus no_of_months from the Saka date.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new(1932,5,1);
    print "Saka 1:" . $saka->as_string() . "\n";
    $saka->minus_months(2);
    print "Saka 2:" . $saka->as_string() . "\n";

=cut

sub minus_months
{
    my $self = shift;
    my $no_of_months = shift;
    croak("ERROR: Invalid month count.\n")
        unless ($no_of_months =~ /^\d+$/);

    if (($self->{mm}-$no_of_months) < 1)
    {
        while (($self->{mm}-$no_of_months) < 1)
        {
            my $_mm = $no_of_months - $self->{mm};
            $self->{yyyy}--;
            $no_of_months = $no_of_months - $self->{mm};
            $self->{mm} = 12;
        }
    }
    $self->{mm} -= $no_of_months;

    return;
}

=head2 add_years(no_of_years)

Add no_of_years to the Saka date.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new(1932,1,1);
    print "Saka 1:" . $saka->as_string() . "\n";
    $saka->add_years(2);
    print "Saka 2:" . $saka->as_string() . "\n";

=cut

sub add_years
{
    my $self = shift;
    my $no_of_years = shift;
    croak("ERROR: Invalid year count.\n")
        unless ($no_of_years =~ /^\d+$/);

    $self->{yyyy} += $no_of_years;

    return;
}

=head2 minus_years(no_of_years)

Minus no_of_years from the Saka date.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new(1932,1,1);
    print "Saka 1:" . $saka->as_string() . "\n";
    $saka->minus_years(2);
    print "Saka 2:" . $saka->as_string() . "\n";

=cut

sub minus_years
{
    my $self = shift;
    my $no_of_years = shift;
    croak("ERROR: Invalid year count.\n")
        unless ($no_of_years =~ /^\d+$/);

    $self->{yyyy} -= $no_of_years;

    return;
}

=head2 get_calendar(yyyy, mm)

Return calendar for given year and month in Saka calendar. It return current month of Saka
calendar if no argument is passed in.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new(1932,1,1);
    print $saka->get_calendar();

    # Print calendar for year 1932 and month 12.
    print $saka->get_calendar(1932, 12);

=cut

sub get_calendar
{
    my $self = shift;
    my $yyyy = shift;    
    my $mm   = shift;

    $yyyy = $self->{yyyy} unless defined $yyyy;
    $mm   = $self->{mm} unless defined $mm;

    _validate_date($yyyy, $mm, 1);

    my ($calendar, $start_index, $days);
    $calendar = sprintf("\n\t%s [%04d]\n", $MONTHS->[$mm-1], $yyyy);
    $calendar .= "\nSun  Mon  Tue  Wed  Thu  Fri  Sat\n";

    $start_index = $self->dow($yyyy, $mm, 1);
    $days = $self->days_in_year_month($yyyy, $mm);
    map { $calendar .= "     " } (1..($start_index%=7));
    foreach (1 .. $days) 
    {
        $calendar .= sprintf("%3d  ", $_);
        $calendar .= "\n" unless (($start_index+$_)%7);
    }
    return sprintf("%s\n\n", $calendar);
}

=head2 to_gregorian(yyyy, mm, dd)

Convert Saka date to Gregorian date and return a list in the format yyyy,mm,dd.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new();
    print "Saka: " . $saka->as_string() . "\n";
    my ($yyyy, $mm, $dd) = $saka->to_gregorian();
    print "Gregorian [$yyyy] Month [$mm] Day [$dd]\n";

=cut

sub to_gregorian
{
    my $self = shift;
    my $yyyy = shift;
    my $mm   = shift;
    my $dd   = shift;

    $yyyy = $self->{yyyy} unless defined $yyyy;
    $mm   = $self->{mm}   unless defined $mm;
    $dd   = $self->{dd}   unless defined $dd;

    _validate_date($yyyy, $mm, $dd);

    return _julian_to_gregorian($self->to_julian($yyyy, $mm, $dd));
}

=head2 from_gregorian(yyyy, mm, dd)

Convert Gregorian date to Saka date and return a list in the format yyyy,mm,dd.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new();
    print "Saka 1: " . $saka->as_string() . "\n";
    my ($yyyy, $mm, $dd) = $saka->from_gregorian(2011, 3, 17);
    print "Saka 2: Year[$yyyy] Month [$mm] Day [$dd]\n";

=cut

sub from_gregorian
{
    my $self = shift;
    my $yyyy = shift;
    my $mm   = shift;
    my $dd   = shift;

    _validate_date($yyyy, $mm, $dd);

    return $self->from_julian(_gregorian_to_julian($yyyy, $mm, $dd));
}

=head2 to_julian(yyyy, mm, dd)

Convert Julian date to Saka date and return a list in the format yyyy,mm,dd.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new();
    print "Saka  : " . $saka->as_string() . "\n";
    print "Julian: " . $saka->to_julian() . "\n";

=cut

sub to_julian
{
    my $self = shift;
    my $yyyy = shift;
    my $mm   = shift;
    my $dd   = shift;

    $yyyy = $self->{yyyy} unless defined $yyyy;
    $mm   = $self->{mm}   unless defined $mm;
    $dd   = $self->{dd}   unless defined $dd;

    _validate_date($yyyy, $mm, $dd);

    my ($gyear, $gday, $start, $julian);
    $gyear = $yyyy + 78;
    $gday  = (_is_leap($gyear)) ? (21) : (22);
    $start = _gregorian_to_julian($gyear, 3, $gday);

    if ($mm == 1)
    {
        $julian = $start + ($dd - 1);
    } 
    else 
    {
        my ($chaitra, $_mm);
        $chaitra = (_is_leap($gyear)) ? (31) : (30);
        $julian = $start + $chaitra;
        $_mm = $mm - 2;
        $_mm = min($_mm, 5);
        $julian += $_mm * 31;
        
        if ($mm >= 8) 
        {
            $_mm     = $mm - 7;
            $julian += $_mm * 30;
        }
        $julian += $dd - 1;
    }

    return $julian;
}

=head2 from_julian()

Convert Julian date to Saka date and return a list in the format yyyy,mm,dd.

    use strict; use warnings;
    use Calendar::Saka;

    my $saka = Calendar::Saka->new();
    print "Saka 1: " . $saka->as_string() . "\n";
    my $julian = $saka->to_julian();
    my ($yyyy, $mm, $dd) = $saka->from_julian($julian);
    print "Saka 2: Year[$yyyy] Month [$mm] Day [$dd]\n";

=cut

sub from_julian
{
    my $self   = shift;
    my $julian = shift;

    my ($day, $month, $year);    
    my ($chaitra, $yyyy, $yday, $mday);
    $julian = floor($julian) + 0.5;
    $yyyy   = (_julian_to_gregorian($julian))[0];
    $yday   = $julian - _gregorian_to_julian($yyyy, 1, 1);     
    $chaitra = _days_in_chaitra($yyyy);
    $year   = $yyyy - $SAKA;  

    if ($yday < $START) 
    {
        $year--;
        $yday += $chaitra + (31 * 5) + (30 * 3) + 10 + $START;
    }

    $yday -= $START;
    if ($yday < $chaitra) 
    {
        $month = 1;
        $day   = $yday + 1;
    }
    else 
    {
        $mday = $yday - $chaitra;
        if ($mday < (31 * 5)) 
        {
            $month = floor($mday / 31) + 2;
            $day   = ($mday % 31) + 1;
        }
        else
        {
            $mday -= 31 * 5;
            $month = floor($mday / 30) + 7;
            $day   = ($mday % 30) + 1;
        }
    }

    return ($year, $month, $day);
}

sub _gregorian_to_julian
{
    my $yyyy = shift;
    my $mm   = shift;
    my $dd   = shift;

    return ($GREGORIAN_EPOCH - 1) +
           (365 * ($yyyy - 1)) +
           floor(($yyyy - 1) / 4) +
           (-floor(($yyyy - 1) / 100)) +
           floor(($yyyy - 1) / 400) +
           floor((((367 * $mm) - 362) / 12) +
           (($mm <= 2) ? 0 : (_is_leap($yyyy) ? -1 : -2)) +
           $dd);
}

sub _julian_to_gregorian
{
    my $julian = shift;

    my $wjd        = floor($julian - 0.5) + 0.5;
    my $depoch     = $wjd - $GREGORIAN_EPOCH;
    my $quadricent = floor($depoch / 146097);
    my $dqc        = $depoch % 146097;
    my $cent       = floor($dqc / 36524);
    my $dcent      = $dqc % 36524;
    my $quad       = floor($dcent / 1461);
    my $dquad      = $dcent % 1461;
    my $yindex     = floor($dquad / 365);
    my $year       = ($quadricent * 400) + ($cent * 100) + ($quad * 4) + $yindex;

    $year++ unless (($cent == 4) || ($yindex == 4));

    my $yearday = $wjd - _gregorian_to_julian($year, 1, 1);
    my $leapadj = (($wjd < _gregorian_to_julian($year, 3, 1)) ? 0 : ((_is_leap($year) ? 1 : 2)));
    my $month   = floor(((($yearday + $leapadj) * 12) + 373) / 367);
    my $day     = ($wjd - _gregorian_to_julian($year, $month, 1)) + 1;

    return ($year, $month, $day);
}

sub _is_leap
{
    my $yyyy = shift;

    return (($yyyy % 4) == 0) &&
            (!((($yyyy % 100) == 0) && (($yyyy % 400) != 0)));
}

sub _days_in_chaitra
{
    my $yyyy = shift;

    (_is_leap($yyyy)) ? (return 31) : (return 30);
}

sub _validate_date
{
    my $yyyy = shift;
    my $mm   = shift;
    my $dd   = shift;

    croak("ERROR: Invalid year [$yyyy].\n")
        unless (defined($yyyy) && ($yyyy =~ /^\d{4}$/) && ($yyyy > 0));
    croak("ERROR: Invalid month number [$mm].\n")
        unless (defined($mm) && ($mm =~ /^\d{1,2}$/) && ($mm >= 1 || $mm <= 12));
    croak("ERROR: Invalid day number [$dd].\n")
        unless (defined($dd) && ($dd =~ /^\d{1,2}$/) && ($dd >= 1 || $mm <= 31));
}

=head1 AUTHOR

Mohammad S Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-calendar-saka at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Calendar-Saka>.  
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Calendar::Saka

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Calendar-Saka>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Calendar-Saka>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Calendar-Saka>

=item * Search CPAN

L<http://search.cpan.org/dist/Calendar-Saka/>

=back

=head1 ACKNOWLEDGEMENTS

This module is based on javascript code written by John Walker founder of Autodesk, Inc. and co-author of AutoCAD.

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Mohammad S Anwar.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=head1 DISCLAIMER

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

1; # End of Calendar::Saka