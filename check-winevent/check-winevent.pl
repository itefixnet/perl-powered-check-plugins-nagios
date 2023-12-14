#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-winevent.pl - Nagios compatible check plugin for Windows eventlogs
#

use strict;
use Getopt::Long;
use Win32;
use Win32::OLE qw( in );
use Time::Duration::Parse;

our $VERSION = "1.3";

our $OK = 0;
our $WARNING = 1;
our $CRITICAL = 2;
our $UNKNOWN = 3;

our %status_text = (
	$OK => "OK",
	$WARNING => "WARNING",
	$CRITICAL => "CRITICAL",
	$UNKNOWN => "UNKNOWN"
);

our @log = ();
our @code = ();
our @type = ();
our @source = ();
our $window = undef;
our $warning = undef;
our $critical = undef;
our $verbose = 0;
 
GetOptions (
	"log=s" => \@log,
	"code=s" => \@code,
	"type=s" => \@type,
	"source=s" => \@source,
	"window=s" => \$window,
	"warning=i" => \$warning,
	"critical=i" => \$critical,
	"verbose+" => \$verbose,
	"help" => sub { PrintUsage(); exit 0 },
) or ExitProgram($UNKNOWN, "Usage problem");

# Process comma separated values
@log = split(",", join(',',@log));
@code = split(",", join(',',@code));
@type = split(/,/, join(',',@type));
@source = split(/,/, join(',',@source));

# Set defaults for non specified parameters
# all sources, all codes, all types, all sources

if (scalar @log == 0) # no log specified, all logs
{
	my $result = {'Top' => {} };
	WMI(Win32::NodeName(), "select * from Win32_NTEventlogFile", $result->{'Top'}, "LogfileName");
	push @log, keys %{$result->{Top}};
}
$verbose && print "Event log(s): " . join(', ', @log) . "\n";

(scalar @code) || ($code[0] = 'all');
$verbose && print "Event code(s): " . join(', ', @code) . "\n";

(scalar @type) || ($type[0] = 'all');
$verbose && print "Event type(s): " . join(', ', @type) . "\n";

(scalar @source) || ($source[0] = 'all');
$verbose && print "Event sources: " . join(', ', @source) . "\n";

# Time window is 1 hour by default
my $lwin = parse_duration($window || "1 hour");
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time - $lwin);
my $timestamp = sprintf ("%04d%02d%02d%02d%02d%02d.000000+000",
	$year+1900, $mon+1, $mday, $hour, $min, $sec);
$verbose && print "Time window: $lwin seconds, timestamp: $timestamp\n";

my $nevents = 0;

foreach my $eventlog (@log)
{
	# Create WQL query
	my $wql = "select * from Win32_NTLogEvent where Logfile='$eventlog' And (TimeGenerated > '$timestamp')";

	if ($code[0] ne 'all')
	{		
		$wql .= "  And (" . CreateWql("EventCode", \@code) . ")";
	}

	if ($type[0] ne 'all')
	{
		$wql .= "  And (" . CreateWql("Type", \@type) . ")";
	}

	if ($source[0] ne 'all')
	{	
		$wql .= "  And (" . CreateWql("SourceName", \@source) . ")";
	}

	($verbose > 1) && print "WQL string generated for $eventlog: $wql\n";

	my $wmiresult = {'Top' => {} };
	WMI(Win32::NodeName(), $wql, $wmiresult->{'Top'}, "RecordNumber");
	($verbose > 2) && print "Records selected: " . join (",", keys %{$wmiresult->{Top}}) . "\n";

	my $n = scalar keys %{$wmiresult->{Top}};
	$nevents += $n;
	$verbose && print "Eventlog $eventlog - $n selected events\n";
}

$verbose && print "Total number of events selected: $nevents\n";

my $result = $OK;	
defined $warning && ($nevents > $warning) && ($result = $WARNING);
defined $critical && ($nevents > $critical) && ($result = $CRITICAL);
	
my $message = "$nevents events|events=$nevents;" .
	((defined $warning ? $warning : "") . ";" . (defined $critical ? $critical : "") . ";");
		
ExitProgram($result, $message);

#### SUBROUTINES ####

##### Create WQL query for a set of elements (could be negated)
#
sub CreateWql
{
	my $prop = shift;
	my $elements = shift;
	
	my $res = "";
	my $lres = "";

	my @negated = grep(/^!/, @{$elements});
	my @non_negated = grep (/^[^!]/, @{$elements});
	
	if (@negated)
	{
		$res .= "(";
		
		$lres = join (' ', map ("$_ And", map("$prop<>'" . substr($_,1) . "'", @negated)));
		$lres =~ s/(.*)And$/$1/; # remove last And
		
		$res .= ((scalar @negated > 1) ? "($lres)" : $lres);
		
		$res .= ")";
	}
	
	$res .= " Or " if @negated && @non_negated;
	
	if (@non_negated)
	{
		$res .= "(";
		
		$lres = join (' ', map ("$_ Or", map("$prop='$_'", @non_negated)));
		$lres =~ s/(.*)Or$/$1/; # remove last Or
		
		$res .= ((scalar @negated > 1) ? "($lres)" : $lres);
		
		$res .= ")";
	}

	return $res;
}
##### PrintUsage #####
sub PrintUsage
{
print "
Usage:
    check-winevent [ [ --log event log[,event log ...] ] ... ] [ [ --code
    event code[,event code ...] ] ... ] [ [ --type event type[,event type
    ...] ] ... ] [ [ --source event source[,event source ...] ] ... ] [
    --window time window ] [--warning *threshold*] [--critical *threshold*]
    [--verbose] [--help]

Options:
    --log event log[,event log ...] ] ...
        Specifies event logs you want to monitor. You can supply comma
        separated values as well as multiple --log options. Optional.
        Defaults to all available event logs on the system.

    --code event code[,event code ...] ] ...
        Specifies event codes you want to monitor. You can supply comma
        separated values as well as multiple --code options. In addition,
        you may negate an event code by prepending a ! (like !1904).
        Optional. Defaults to all event codes.

    --type event type[,event type ...] ] ...
        Specifies event types you want to monitor. You can supply comma
        separated values as well as multiple --type options. In addition,
        you may negate an event type by prepending a ! (like !warning).
        Available event types: (case insensitive):

         - information
         - warning
         - error
         - audit failure
         - audit success

        Optional. Defaults to all event types.

    --source event source[,event source ...] ] ...
        Specifies event sources you want to monitor. You can supply comma
        separated values as well as multiple --source options. In addition,
        you may negate an event source by prepending a ! (like !W32Time).
        Optional. Defaults to all event sources.

    --window time window
        Process events within the last time value. You may specify a time
        value in free form like \"5 minutes and 10 seconds\". Optional.
        Defaults to '1 hour'.

    --warning *threshold*
        Returns WARNING exit code if the selected number of events is above
        the *threshold*. Optional.

    --critical *threshold*
        Returns CRITICAL exit code if the selected number of events is above
        the *threshold*. Optional.

    --verbose
        Produces some output for debugging or to see individual values of
        samples. Multiple values are allowed.

    --help
        Produces a help message.

"

}
##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;	
	print "EVENT $status_text{$exitcode} - $message";
	exit ($exitcode);
}

sub WMI
{
	my ($computername, $query, $result_hash, $groupby) = @_;
	
	my $wmi;

	($wmi = Win32::OLE->GetObject ("WinMgmts://$computername"))|| return undef;
	
    my $query_results = $wmi->ExecQuery($query);
	
	scalar(in($query_results)) || return undef;
	
    foreach my $pc (in ($query_results))
	{
	
		my $object;
		
		# find group by value
		my $groupbyvalue = undef;
		foreach $object (in $pc->{Properties_})
		{
			($object->{Name} eq $groupby) || next;
			$groupbyvalue = $object->{Value};
			last;
		}
		
		$groupbyvalue || return; # we require group by
		
		foreach my $object (in $pc->{Properties_})
		{	
			$result_hash->{$groupbyvalue}{$object->{Name}} = $object->{Value};
		}
	}
}

__END__

=head1 NAME

check-winevent - Nagios compatible check plugin for Windows eventlogs

=head1 SYNOPSIS

B<check-winevent> [ [ B<--log> event log[,event log ...] ] ... ] [ [ B<--code> event code[,event code ...] ] ... ] [ [ B<--type> event type[,event type ...] ] ... ] [ [ B<--source> event source[,event source ...] ] ... ] [ B<--window> time window ] [B<--warning> I<threshold>] [B<--critical> I<threshold>] [B<--verbose>] [B<--help>]

=head1 DESCRIPTION

B<check-winevent> is a Nagios plugin to monitor event logs on the local Windows system. You can filter events based on time, code, type and source. Negation is also possible for code, type and source. check-winevent is capable of scanning multiple event logs.

=head1 OPTIONS

=over 4

=item B<--log> event log[,event log ...] ] ...

Specifies event logs you want to monitor. You can supply comma separated values as well as multiple --log options. Optional. Defaults to all available event logs on the system.

=item B<--code> event code[,event code ...] ] ...

Specifies event codes you want to monitor. You can supply comma separated values as well as multiple --code options. In addition, you may negate an event code by prepending a B<!> (like !1904). Optional. Defaults to all event codes.

=item B<--type> event type[,event type ...] ] ...

Specifies event types you want to monitor. You can supply comma separated values as well as multiple --type options. In addition, you may negate an event type  by prepending a B<!> (like !warning). Available event types: (case insensitive):

 - information
 - warning
 - error
 - audit failure
 - audit success

Optional. Defaults to all event types.

=item B<--source> event source[,event source ...] ] ...

Specifies event sources you want to monitor. You can supply comma separated values as well as multiple --source options. In addition, you may negate an event source by prepending a B<!> (like !W32Time). Optional. Defaults to all event sources.

=item B<--window> I<time value>

Process events within the last I<time value>. You may specify a time value in free form like "5 minutes and 10 seconds". Optional. Defaults to '1 hour'.

=item B<--warning> I<threshold>

Returns WARNING exit code if the selected number of events is above the I<threshold>. Optional.

=item B<--critical> I<threshold>

Returns CRITICAL exit code if the selected number of events is above the I<threshold>. Optional.

=item B<--verbose>

Produces some output for debugging or to see individual values of samples. Multiple values are allowed.

=item B<--help>

Produces a help message.

=back

=head1 EXAMPLES

 check-winevent --type error --window "5 minutes" --critical 0

Scans all event logs available on the system and returns CRITICAL if there was at least one error event last 5 minutes.

 check-winevent --log application --source "Application Hang","Application Error" --type error --warning 10 --critical 100

Scans application event log for events occurred during the last hour and returns WARNING or CRITICAL if the number of events exceed 10 or 100 respectively.

 check-winevent --log security --window "30 minutes" --type "audit failure"

Scans security event log and returns CRITICAL if there was at least one audit failure event during the last 30 minutes.

=head1 EXIT VALUES

 0 OK
 1 WARNING
 2 CRITICAL
 3 UNKNOWN

=head1 AUTHOR

Tevfik Karagulle L<http://www.itefix.net>

=head1 SEE ALSO

=over 4

=item Nagios web site L<http://www.nagios.org>

=item Perl Time::Duration::Parse documentation L<http://search.cpan.org/~miyagawa/Time-Duration-Parse-0.06/lib/Time/Duration/Parse.pm>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License. L<http://www.opensource.org/licenses/artistic-license.php>

=head1 VERSION

Version 1.3, January 2014

=head1 CHANGELOG

=over 4

=item Changes from 1.2

 - Bug fix: Improper combination of multiple negated elements in the generated WQL string. See Itefix forum topic https://www.itefix.no/i2/content/problem-checkwinevent-multiple-code-exclusions for more info.
 - New packaging - faster start

=item Changes from 1.1

 - use UTC instead of localtime as WMI delivers event entries with UTC-time

=item Changes from 1.0

 -typo status code SERVICE -> EVENT

=item Initial release

=back

=cut