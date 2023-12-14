#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-winprocess.pl - Nagios compatible check plugin for Windows processes
#
# Requirement: TASKLIST.EXE TASKKILL.EXE

use strict;
use warnings;
use Getopt::Long;
use Win32;
use Win32::API;

Win32::API->Import(
 "user32", 
 "BOOL OemToCharBuff(LPCTSTR lpszSrc, LPTSTR lpszDst, DWORD cchDstLength)"
);

our $VERSION = "1.6";

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

our @filters = ();
our $tasklist;
our $numtasks;
our $firstprocs;

our $critical = undef;
our $warning = undef;
our $kill = 0;
our $verbose = 0;
our $compare = 'gt'; # type of comprison operator for critical/warning thresholds (gt, eq, lt)
our $first = 0;

GetOptions (
	"filter=s" => \@filters,
	"critical=s" => \$critical,
	"warning=s" => \$warning,
	"compare=s" => sub { $compare = lc $_[1] },
	"help" => sub { PrintUsage() },
	"verbose" => sub { $verbose++ },
	"kill" => \$kill,
	"first=i" => \$first
) || ExitProgram($UNKNOWN, "Usage problem");

grep (/$compare/, split (',', 'eq,ne,gt,ge,lt,le')) || ExitProgram($UNKNOWN, "Unsupported compare operator: $compare");
@filters = split(/,/, join(',', @filters)); # Treat comma-separated values as well

# Compose tasklist command
$tasklist = "tasklist /nh /fo csv " . join (" ", map ("/FI \"$_\"", @filters));
print "Command to gather info: $tasklist\n" if $verbose;

open TASKLIST, "$tasklist |" or ExitProgram($UNKNOWN, "Problems with tasklist.exe");

$numtasks = 0;
$firstprocs = "";

while (<TASKLIST>)
{
	# remove quotes and non-printables
	my $line = $_;
	$line =~ s/\"//g;
	OemToCharBuff($line, $line, length($line));

	# extract tokens from a csv list
	my @inarr = split /,/, $line;
	
	# the first two arguments are process name and pid (reqd)
	($inarr[0] && $inarr[1]) || next;
	
	print "$inarr[0] ($inarr[1]), " if $verbose;
	$numtasks++;

	# Treat first option
	$first && ($numtasks <= $first) && ($firstprocs .= "$inarr[0] ");
	
	# kill the process if kill option is specified AND at least one filter is specified
	next if not ($kill and scalar @filters > 0);
	my $killcmd = "taskkill /T /F /PID $inarr[1]";
	print "Command to kill: $killcmd\n" if $verbose;
	system ("$killcmd > nul");
}

close TASKLIST;

my $state = $OK;
defined $warning && IsThreshold($numtasks, $warning, $compare) && ($state = $WARNING);
defined $critical && IsThreshold($numtasks, $critical, $compare) && ($state = $CRITICAL);

my $perfdata = "|processes=$numtasks;" . (defined $warning ? $warning : "") . ";" . (defined $critical ? $critical : "") . ";";
ExitProgram($state, "$numtasks process(es)" . (($first) ? " ($firstprocs ... )" : "") . (($kill) ? " (killed)" : "") . $perfdata);

#### SUBROUTINES ####

##### PrintUsage #####
sub PrintUsage
{
	print "
Usage:
    check-winprocess [--filter *filter spec*[,*filter spec*] ... ] ... ]
    [--warning *threshold*] [--critical *threshold*] [--compare *operator*]
    [--first *number*] [--kill] [--verbose] [--help]

Options:
    --filter *filter spec*[,*filter spec*] ... ] ... ]
        Specify filters to select processes. A *filter spec* consists of
        three fields: filter name, operator and value. You can specify
        several comma separated filters for one --filter option, as well as
        several --filter options. Defaults to all processes if no filter is
        defined. List of filters available (see tasklist documentation for
        more help):

         Filter Name     Valid Operators           Valid Value(s)
         -----------     ---------------           --------------
         STATUS          eq, ne                    RUNNING | NOT RESPONDING
         IMAGENAME       eq, ne                    Image name
         PID             eq, ne, gt, lt, ge, le    PID value
         SESSION         eq, ne, gt, lt, ge, le    Session number
         SESSIONNAME     eq, ne                    Session name
         CPUTIME         eq, ne, gt, lt, ge, le    CPU time in the format
                                                   of hh:mm:ss.
                                                   hh - hours,
                                                   mm - minutes, ss - seconds
         MEMUSAGE        eq, ne, gt, lt, ge, le    Memory usage in KB
         USERNAME        eq, ne                    User name in [domain\]user
                                                   format
         SERVICES        eq, ne                    Service name
         WINDOWTITLE     eq, ne                    Window title
         MODULES         eq, ne                    DLL name

    --warning *threshold*
        Return WARNING if the number of processes matching the criteria is
        more than *threshold*. Optional.

    --critical *threshold*
        Return CRITICAL if the number of processes matching the criteria is
        more than *threshold*. Optional.

    --compare *operator*
        Specify the type of comparison operator for threshold checks.
        Optional. Available values are:

         'eq'  equal to
         'ne'  not equal
         'gt'  greater than (default!)
         'ge'  greater or equal
         'lt'  less than
         'le'  less or equal

    --first *number*
        List process names as a part of plugin output. The first specified number of processes will be selected. Optional.

    --kill
        Kill the processes matching the filtering criteria. Useful as an
        action handler. Works only if at least one filter is defined.
        Optional.

    --verbose
        Increase output verbosity for debugging.

    --help
        Produce a help message.

	";
}

##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;
	print "PROCESS $status_text{$exitcode} - $message";
	exit ($exitcode);
}

##### IsThreshold #####
sub IsThreshold
{
	my ($value, $threshold, $operand) = @_;
	return
		($operand eq 'eq' and $value == $threshold) || 
		($operand eq 'ne' and $value != $threshold) ||
		($operand eq 'gt' and $value > $threshold) ||
		($operand eq 'ge' and $value >= $threshold) || 
		($operand eq 'lt' and $value < $threshold) ||
		($operand eq 'le' and $value <= $threshold);
}
__END__

=head1 NAME

B<check-winprocess> -  Nagios compatible check plugin for Windows processes

=head1 SYNOPSIS

B<check-winprocess> [B<--filter> I<filter spec>[,I<filter spec>] ... ] ... ] [B<--warning> I<threshold>] [B<--critical> I<threshold>] [B<--compare> I<operator>] [B<--first> I<number>] [B<--kill>] [B<--verbose>] [B<--help>]

=head1 DESCRIPTION

B<check-winprocess> is a Nagios NRPE plugin for checking processes by using criteria like status, name, cpu and memory usage and many more. You can also specify if the processes meeting the criteria will be killed. B<check_process> uses Windows tools I<tasklist> and I<taskkill> (available in XP and later). 

=head1 OPTIONS

=over 4 

=item B<--filter> I<filter spec>[,I<filter spec>] ... ] ... ]

Specify filters to select processes. A I<filter spec> consists of three fields: filter name, operator and value. You can specify several comma separated filters for one --filter option, as well as several --filter options. Defaults to all processes if no filter is defined. List of filters available (see B<tasklist> documentation for more help):

 Filter Name     Valid Operators           Valid Value(s)
 -----------     ---------------           --------------
 STATUS          eq, ne                    RUNNING | NOT RESPONDING
 IMAGENAME       eq, ne                    Image name
 PID             eq, ne, gt, lt, ge, le    PID value
 SESSION         eq, ne, gt, lt, ge, le    Session number
 SESSIONNAME     eq, ne                    Session name
 CPUTIME         eq, ne, gt, lt, ge, le    CPU time in the format
                                           of hh:mm:ss.
                                           hh - hours,
                                           mm - minutes, ss - seconds
 MEMUSAGE        eq, ne, gt, lt, ge, le    Memory usage in KB
 USERNAME        eq, ne                    User name in [domain\]user
                                           format
 SERVICES        eq, ne                    Service name
 WINDOWTITLE     eq, ne                    Window title
 MODULES         eq, ne                    DLL name

=item B<--warning> I<threshold>

Return WARNING if the number of processes matching the criteria is more than I<threshold>. Optional.

=item B<--critical> I<threshold>

Return CRITICAL if the number of processes matching the criteria is more than I<threshold>. Optional.

=item B<--compare> I<operator>

Specify the type of comparison operator for threshold checks. Optional. Available values are:

 'eq'  equal to
 'ne'  not equal
 'gt'  greater than (default!)
 'ge'  greater or equal
 'lt'  less than
 'le'  less or equal

=item B<--first> I<number>

List process names as a part of plugin output. The first specified number of processes will be selected. Optional.

=item B<--kill>

Kill the processes matching the filtering criteria. Useful as an action handler. B<Works only if at least one filter is defined>. Optional. 

=item B<--verbose>

Increase output verbosity for debugging.

=item B<--help>

Produce a help message.

=back

=head1 EXAMPLES

 check-winprocess.exe --warn 100 --critical 300

Checks the total number of processes in memory and returns WARNING for more than 100 processes or CRITICAL for more than 300 processes.

 check-winprocess.exe --filter "imagename eq runaway.exe","cputime gt 01:00:00" --critical 1

Checks if there exists I<runaway.exe> processes with CPU time longer than one hour, returns CRITICAL if there was at least one process.

 check-winprocess.exe --filter "imagename eq A.EXE","imagename eq B.EXE","imagename eq C.EXE" --compare ne --critical 3

Checks if there exists A.EXE, B.EXE and C.EXE processes, returns CRITICAL if the number of processes is not 3.

 check-winprocess.exe --filter "memusage gt 102400" --filter "status eq NOT RESPONDING" --kill --critical 1

Checks if there exists processes with memory consumption more than 100 MB and in I<NOT RESPONDING> state, kills them and returns CRITICAL if there was at least one process.

=head1 EXIT VALUES

 0 OK
 1 WARNING
 2 CRITICAL
 3 UNKNOWN

=head1 AUTHOR

Tevfik Karagulle L<http://www.itefix.no>

=head1 SEE ALSO

=over 4

=item Nagios web site L<http://www.nagios.org>

=item Nagios NRPE documentation L<http://nagios.sourceforge.net/docs/nrpe/NRPE.pdf>

=item TASKLIST documentation L<http://technet.microsoft.com/en-us/library/bb491010.aspx>

=item TASKKILL documentation L<http://technet.microsoft.com/en-us/library/bb491009.aspx>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License. L<http://www.opensource.org/licenses/artistic-license.php>

=head1 VERSION

Version 1.6, October 2012

=head1 CHANGELOG

=over 4

=item changes from 1.5

 Introduce option --first allowing to list first number of process names as a part of the plugin output.
 List process names as comma separated list in verbose output (newline creates some problems)

=item changes from 1.4

 produce performance data according to guidelines

=item changes from 1.3

 Proper treatment of 0 as threshold

=item changes from 1.2

 renamed as 'check-winprocess'
 use csv output from tasklist

=item changes from 1.1

 Drop the language specific -no output- check

=item Changes from 1.0

 Add option I<--compare> to specify the type of comparison for threshold checks.
 Treat information about no tasks properly.

=back

=cut
