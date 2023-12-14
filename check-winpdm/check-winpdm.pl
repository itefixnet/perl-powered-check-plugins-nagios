#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-winpdm.pl - Nagios compatible check plugin for Windows processor, disk and memory checks
#
# Requirement: WMIC.EXE for processor checks

use strict;
use warnings;
use Getopt::Long;
use Win32;
use Win32::OLE qw( in );

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
	
our $processor = 0;
our $disk = 0;
our $memory = undef;
our $drive = undef;
our $warning = undef;
our $critical = undef;
our $verbose = 0;
our $psamples = 3;	# number of processor samples
our $pinterval = 2; # interval in seconds between samples
our $hostname = 'localhost';
 
GetOptions (
	"processor" => \$processor,
	"disk" => \$disk,
	"memory:s" => \$memory,
	"drive=s" => \$drive,
	"warning=s" => \$warning,
	"critical=s" => \$critical,
	"psamples=i" => \$psamples,
	"pinterval=i" => \$pinterval,
	"verbose" => \$verbose,
	"help" => sub { PrintUsage() },
) or ExitProgram($UNKNOWN, "Usage problem");


if ($disk)
{
	# Drive must be specified for option disk
	$drive || ExitProgram($UNKNOWN, "Usage problem: Drive.");
}

if (defined $memory)
{
	$memory eq "" && ($memory = 'physical'); $memory = lc $memory; # Normalization ops
	
	($memory eq 'physical' || $memory eq 'virtual' || $memory eq 'pagefile') 
		|| ExitProgram($UNKNOWN, "Usage problem: memory mode.");
}

MAINSW:
{
	$processor && do { CheckProcessor($warning, $critical); last MAINSW; };
 	$disk && do { CheckDisk($drive, $warning, $critical); last MAINSW; };
	$memory	&& do { CheckMemory($warning, $critical); last MAINSW; };
}

#### SUBROUTINES ####

##### CheckProcessor #####
sub CheckProcessor
{
	my ($warning, $critical) = @_;

	my $perfcmd = "wmic cpu get loadpercentage /value /every:$pinterval /repeat:$psamples";
	my $procpct = 0.0;
	my $nm = 0;

	open PERFCTR, " $perfcmd | " or ExitProgram($UNKNOWN, "Processor information problem - open pipe");
	
	while (<PERFCTR>) {	
		next if not /^LoadPercentage/; # only interested lines starting with 'LoadPercentage'	
		
		my ($load) = ($_ =~ /LoadPercentage=(\d+)/);
		print $_ if $verbose;

		(defined $load) || ExitProgram($UNKNOWN, "Processor information problem - parsing.");	
		
		$procpct += $load;
		$nm++;
		print "Processor measurement $nm: " . $load . "%\n" if $verbose;
	}
		
	close PERFCTR;
	
	$procpct = ($procpct) ? ($procpct / $nm) : $procpct;
	my $resultcode = $OK;
	$warning && ($procpct > $warning) && ($resultcode = $WARNING);
	$critical && ($procpct > $critical) && ($resultcode = $CRITICAL);
	
	my $resultmsg = sprintf "usage %.2f%%", $procpct;
	
	# add performance data
	$resultmsg .= 
		"|'processor usage'=" . 
		sprintf ("%.2f", $procpct) . "%;" . 
		(defined $warning ? $warning : "") . ";" . 
		(defined $critical ? $critical : "") . ";";
	
	ExitProgram($resultcode, $resultmsg);
}

##### CheckDisk #####
sub CheckDisk
{
	my ($drive, $warning, $critical) = @_;
	
	my $wmi = Win32::OLE->GetObject("winmgmts://$hostname/root/CIMV2");
	$wmi || ExitProgram($UNKNOWN, "WMI Problem");
	
	my $drivelist = $wmi->ExecQuery("select * from Win32_LogicalDisk where Name='$drive' And DriveType=3");
	$drivelist || ExitProgram($UNKNOWN, "Drive information problem");

	my @tmp = in($drivelist);
	my $driveinfo = pop @tmp;
	$driveinfo || ExitProgram($UNKNOWN, "Drive information problem");
	
	($driveinfo->{FreeSpace} and $driveinfo->{Size}) || ExitProgram($UNKNOWN, "Drive information problem");

	my $diskinuse = $driveinfo->{Size} - $driveinfo->{FreeSpace};	
	my $diskusepct = ($diskinuse /  $driveinfo->{Size}) * 100;
	my $inusemb = $diskinuse / (1024*1024);
	my $totalmb = $driveinfo->{Size} / (1024*1024);
	
	my $resultcode = $OK;
	$warning && ($diskusepct > $warning) && ($resultcode = $WARNING);
	$critical && ($diskusepct > $critical) && ($resultcode = $CRITICAL);
	
	my $resultmsg = sprintf "usage: $drive %.1f MB (%.2f%% of total %.1f MB)", $inusemb, $diskusepct, $totalmb;
	$resultmsg .= 
		"|'disk in use'=" . sprintf ("%.1f", $inusemb) . "MB;" . 
		" 'disk usage'=" . sprintf ("%.2f", $diskusepct) . "%;" .
		((defined $warning ? $warning : "") . ";" . (defined $critical ? $critical : "") . ";") .
		" 'disk total'=" . sprintf ("%.1f", $totalmb) . "MB;";		
	
	ExitProgram($resultcode, $resultmsg);
}

##### CheckMemory #####
sub CheckMemory
{
	my ($warning, $critical) = @_;
	
	my $wmi = Win32::OLE->GetObject("winmgmts://$hostname/root/CIMV2");
	$wmi || ExitProgram($UNKNOWN, "WMI Problem");

	# Get memory info
	my $wqlstring = ($memory eq 'pagefile') ? "select * from Win32_PageFileUsage" : "select * from Win32_OperatingSystem";
	
	my $oslist = $wmi->ExecQuery($wqlstring);
	$oslist || ExitProgram($UNKNOWN, "OS information problem");

	my @tmp = in($oslist);
	my $osinfo = pop @tmp; # hmm, only one instance (one page file?)
	$osinfo || ExitProgram($UNKNOWN, "OS information problem");
	
	my ($total, $free) = (0, 0);
	
	if ($memory eq 'physical')
	{
		$total = $osinfo->{TotalVisibleMemorySize};
		$free = $osinfo->{FreePhysicalMemory};
	} elsif ($memory eq 'virtual')  {
		$total = $osinfo->{TotalVirtualMemorySize};
		$free = $osinfo->{FreeVirtualMemory};
	} elsif ($memory eq 'pagefile') {
		$total = $osinfo->{AllocatedBaseSize} * 1024;
		$free = ($osinfo->{AllocatedBaseSize} - $osinfo->{CurrentUsage}) * 1024;
	} else {
		ExitProgram($UNKNOWN, "Why did this happen ??"); # shouldn't come here at all
	}
	
	($total && $free) || ExitProgram($UNKNOWN, "OS information problem");
		
	my $pfinuse = $total - $free;
	my $pfusepct = ($pfinuse /  $total) * 100;
		
	my $resultcode = $OK;
	$warning && ($pfusepct > $warning) && ($resultcode = $WARNING);
	$critical && ($pfusepct > $critical) && ($resultcode = $CRITICAL);
		
	my $resultmsg = sprintf ucfirst($memory) . " usage: %d MB (%d%% of %d MB)", $pfinuse / 1024, $pfusepct, $total / 1024;
	
		$resultmsg .= 
		"|'memory in use'=" . sprintf ("%d", $pfinuse / 1024). "MB;" . 
		" 'memory usage'=" . sprintf ("%d", $pfusepct) . "%;" .
		((defined $warning ? $warning : "") . ";" . (defined $critical ? $critical : "") . ";") .
		" 'memory total'=" . sprintf ("%d", $total / 1024) . "MB;";
		
	ExitProgram($resultcode, $resultmsg);
	
}

##### PrintUsage #####
sub PrintUsage
{
print "
Usage:
    check-winpdm [ [ --processor [--psamples *count*] [--pinterval
    *milliseconds*] ] | [ --disk [--drive *drive letter with colon*] ] | [
    --memory [ *physical|virtual|pagefile* ] ] ] [--warning *threshold*]
    [--critical *threshold*] [--verbose] [--help]

Options:
    --processor
        Checks processor utilization by collecting three samples with
        two-seconds intervals and returns the average as default. Number of
        samples and interval can be adjusted by the options *--psamples* and
        *--pinterval*.

    --disk
        Checks local disk utilization by using WMI. Option --drive must be
        specified.

    --drive *local drive letter with colon*
        Disk only. Specifies the local drive for utilization measurement.

    --memory [ *physical|virtual|pagefile* ]
        Checks physical, virtual or pagefile memory utilization by using
        WMI. Default is physical.

    --warning *threshold*
        Returns WARNING exit code if the measured value is above the
        *threshold*.

    --critical *threshold*
        Returns CRITICAL exit code if the measured value is above the
        *threshold*.

    --psamples *count*
        Processor only. Specifies the number of samples for calculation of
        processor usage. Default is 3.

    --pinterval *seconds*
        Processor only. Specifies the interval in milliseconds between
        samples. Default is 2.

    --verbose
        Produces some output for debugging or to see individual values of
        samples.

    --help
        Produces a help message.

		
"

}
##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;
	
	my $lcomp = (($disk)?"DISK":(($memory)?"MEMORY":(($processor)?"PROCESSOR":"UNKNOWN")));
	print "$lcomp $status_text{$exitcode} - $message";
	exit ($exitcode);
}


__END__

=head1 NAME

check-winpdm - Nagios compatible check plugin for Windows processor, disk and memory checks

=head1 SYNOPSIS

B<check-winpdm> [ [ B<--processor> [B<--psamples> I<count>] [B<--pinterval> I<seconds>] ] | [ B<--disk> [B<--drive> I<drive letter with colon>] ] | [ B<--memory> [ I<physical|virtual|pagefile> ] ] ] [B<--warning> I<threshold>] [B<--critical> I<threshold>] [B<--verbose>] [B<--help>]

=head1 DESCRIPTION

B<check-winpdm> is a Nagios plugin to monitor basic resources of processor, disk and memory on the local Windows system.

=head1 OPTIONS

=over 4

=item B<--processor>

Checks processor utilization by collecting three samples with two-seconds intervals and returns the average as default. Number of samples and interval can be adjusted by the options I<--psamples> and I<--pinterval>.

=item B<--disk>

Checks local disk utilization by using WMI. Option B<--drive> must be specified.

=item B<--drive> I<local drive letter with colon>

Disk only. Specifies the local drive for utilization measurement.

=item B<--memory> [ I<physical|virtual|pagefile> ]

Checks physical, virtual or pagefile memory utilization by using WMI. Default is physical.

=item B<--warning> I<threshold>

Returns WARNING exit code if the measured value is above the I<threshold>.

=item B<--critical> I<threshold>

Returns CRITICAL exit code if the measured value is above the I<threshold>.

=item B<--psamples> I<count>

Processor only. Specifies the number of samples for calculation of processor usage. Default is 3.

=item B<--pinterval> I<seconds>

Processor only. Specifies the interval in seconds between samples. Default is 2.

=item B<--verbose>

Produces some output for debugging or to see individual values of samples.

=item B<--help>

Produces a help message.

=back

=head1 EXAMPLES

 check-winpdm --processor --warning 60 --critical 90 --psamples 10 --pinterval 5

Calculates an average CPU utilization value by sampling the related performance counter 10 times with 5-seconds intervals. In addition to a one-line status output, it also returns CRITICAL if the calculated value is above 90, WARNING if it is above 60 or NORMAL otherwise.

 check-winpdm --disk --drive C: -w 97.5 -c 99.5

Gets utilization of C: drive, produces a one-line status output, returns CRITICAL if the measured value is above 97.5%, WARNING if it is above 99.5% or NORMAL otherwise.

 check-winpdm --memory -w 90 -c 99

Gets information about physical memory usage, produces a one-line status output, returns CRITICAL if the measured value is above 99, WARNING if it is above 90 or NORMAL otherwise.

 check-winpdm --memory pagefile -w 80 -c 95

Gets information about pagefile usage, produces a one-line status output, returns CRITICAL if the measured value is above 95, WARNING if it is above 80 or NORMAL otherwise.

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

=item typeperf documentation L<http://www.microsoft.com/resources/documentation/windows/xp/all/proddocs/en-us/nt_command_typeperf.mspx?mfr=true>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License. L<http://www.opensource.org/licenses/artistic-license.php>

=head1 VERSION

Version 1.6, April 2016

=head1 CHANGELOG

=over 4

=item Changes from 1.5

 - use WMIC for processor checks

=item Changes from 1.4

 - produce performance data according to guidelines

=item Changes from 1.3

 - Processor measurements are made via 'top' tool on Cygwin.

=item Changes from 1.2

 - Use Win32::Perflib (ref http://www.jkrb.de/jmk/showsource.asp?f=data/scripts/processor.pl)
 - option --memory accepts three value for different types of memory checks: I<physical> (default), I<virtual> and I<pagefile>

=item Changes from 1.1

 - processor: Change time interval unit from seconds to milliseconds
 - processor: Use perl module instead of the external tool typeperf

=item Changes from 1.0

 - use CRITICAL instead of ERROR
 - New option --verbose to produce some additional information for debugging or monitoring.
 - Processor. Two new options: --psamples and --pinterval
 - Disk. Total disk size is also printed.
 - Memory. Page file is monitored instead of physical memory.

=back

=cut
