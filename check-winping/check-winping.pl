#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-winping.pl - Nagios compatible check plugin for Windows ping checks
#

use strict;
use warnings;
use Getopt::Long;
use FindBin qw($RealBin);

our $VERSION = "1.5";

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

our $hostname = undef;
our $ip4 = 1;
our $ip6 = 0;
our $warning = undef;
our $critical = undef;
our $packets = 5;
our $timeout = 10;
our $buffersize = undef;
our $verbose = 0;
		
GetOptions (
	"H|hostname=s" => \$hostname,
	"4|use-ipv4" => \$ip4,
	"6|use-ipv6" => \$ip6,
	"warning=s" => \$warning,
	"critical=s" => \$critical,
	"packets=i" => \$packets,
	"buffersize=i" => \$buffersize,
	"timeout=i" => \$timeout,
	"verbose" => sub { $verbose++ },
	"help" => sub { PrintUsage(); exit 0; }
) or ExitProgram($UNKNOWN, "Usage problem");

($hostname && $warning && $critical)
	|| ExitProgram($UNKNOWN, "Hostname, thresholds warning and critical are required parameters.");
	
$packets || ExitProgram($UNKNOWN, "Number of packets is 0?.");

our ($warning_round_trip_average, $warning_packet_loss_ratio) = ($warning =~ /([\d\.]+),(\d+)\%/);
our ($critical_round_trip_average, $critical_packet_loss_ratio) = ($critical =~ /([\d\.]+),(\d+)\%/);

($warning_round_trip_average && $warning_packet_loss_ratio && $critical_round_trip_average && $critical_packet_loss_ratio)
	|| ExitProgram($UNKNOWN, "Could not determine at least one round trip/packet loss value for warning/critical thresholds.");

my $pingexe = "$RealBin/ping.exe";
my $ping6exe = "$RealBin/ping6.exe";
	
our $ping_command = 
	'"'. ($ip4 ? $pingexe : $ping6exe) . '"' .
	" -n " . $packets . 
	" -w " . $timeout * 1000 .
	($buffersize ? (" -l $buffersize") : "") .
	" $hostname";

print "Ping command: $ping_command\n" if $verbose;

my $measured_round_trip_average = undef;
my $measured_packet_loss_rate = undef;

open PINGOUT, "$ping_command |"
#open PINGOUT, "pingtest" 
	or ExitProgram($UNKNOWN, "Problems during ping execution.");

# positions w/o blank lines
my ($loss_line, $average_line, $response_start, $response_end) = (3 + $packets, 5 + $packets, 2, 1 + $packets);

my $lc = 0;

while (<PINGOUT>)
{
	/\S+/ || next;
	
	$lc++;	
	print "$lc: $_" if $verbose > 1;

	if ($lc >= $response_start and $lc <= $response_end)
	{
		my ($message) = ($_ =~ /: (.*)/);
		defined $message || ExitProgram($UNKNOWN, "No response");
		print "Response from ping: $message\n" if $verbose > 2;
		next if $message =~ /TTL=\d+/;
		# response from ping is not as expected, quit with error
		ExitProgram($UNKNOWN, "Not expected input - $message");		
	} elsif ($lc == $loss_line) {
		($measured_packet_loss_rate) = ($_ =~ /(\d+)\%/);
	} elsif ($lc == $average_line) {
		my ($t1, $t2, $t3) = split /,/;
		($measured_round_trip_average) = ($t3 =~ /(\d+)\s?ms/);
	} 
}

close PINGOUT;

print "\n\$measured_round_trip_average = $measured_round_trip_average, \$measured_packet_loss_rate = $measured_packet_loss_rate\n" if $verbose > 1;

(defined $measured_round_trip_average && defined $measured_packet_loss_rate) || ExitProgram($CRITICAL, "No response from $hostname.");

my $results = "Round trip: $measured_round_trip_average ms, Packet loss: $measured_packet_loss_rate%, packets: $packets";

$results .= 
		"|'round trip'=" . $measured_round_trip_average . "ms;" . 
		(defined $warning_round_trip_average ? $warning_round_trip_average : "") . ";" . 
		(defined $critical_round_trip_average ? $critical_round_trip_average : "") . ";" .
		" 'packet loss rate'=" . $measured_packet_loss_rate . "%;" .
		(defined $warning_packet_loss_ratio ? $warning_packet_loss_ratio : "") . ";" . 
		(defined $critical_packet_loss_ratio ? $critical_packet_loss_ratio : "") . ";" . 
		" packets=" . $packets . ";";

(($measured_round_trip_average >= $critical_round_trip_average) || ($measured_packet_loss_rate >= $critical_packet_loss_ratio))
	&& ExitProgram($CRITICAL, $results);

(($measured_round_trip_average >= $warning_round_trip_average) || ($measured_packet_loss_rate >= $warning_packet_loss_ratio))
	&& ExitProgram($WARNING, $results);
	
ExitProgram($OK, $results);

sub ExitProgram
{
	my ($exitcode, $message) = @_;

	print "WINPING $status_text{$exitcode} - $message";
	exit ($exitcode);
}

sub PrintUsage
{
print "
Usage:
    check-winping [ -H | --hostname ] *host* --warning *threshold* --critical
    *threshold* [ [ -4 | --use-ip4 ] | [ -6 | --use-ipv6 ] ] [ --packets
    *number of packets* ] [ --buffersize *number of bytes* ] [ --timeout
    *seconds* ] [ --verbose .. ] [ --help ]

Options:
    -H|--hostname *host*
        Hostname to ping. Required.

    --warning *threshold*
        Return WARNING if measured values are at least the threshold values.
        A *threshold* is specified as a combination of round trip time and
        packet loss ratio with the following format : round-trip-time in
        milliseconds,packet-losss-ratio%. Example: 100,80%. Required.

    --warning *threshold*
        Return CRITICAL if measured values are at least the threshold
        values. A *threshold* is specified as a combination of round trip
        time and packet loss ratio with the following format :
        round-trip-time in milliseconds,packet-losss-ratio%. Example:
        100,80%. Required.

    -4|--use-ip4
        Use IPv4 connection (standard Windows ping.exe). Optional. Default
        is on.

    -6|--use-ip6
        Use IPv6 connection (standard Windows ping6.exe). Optional. Default
        is off.

    --packets *number of packets*
        Specify the number of packets to send during pinging. Optional.
        Default is 5 packets.

    --buffersize *number of bytes*
        Specify buffer size for ping packets. Optional. Default is 32 bytes.

    --timeout *seconds*
        Specify ping timeout in seconds. Optional. Default is 10 seconds.

    --verbose
        Produces detailed output for debugging. Optional. Can be specified
        up to twice for increasing verbosity.

    --help
        Produces a help message.

";
}

__END__

=head1 NAME

B<check-winping> - Nagios compatible check plugin for Windows ping checks

=head1 SYNOPSIS

B<check-winping> [ B<-H | --hostname> ] I<host> B<--warning> I<threshold> B<--critical> I<threshold> [ [ B<-4 | --use-ip4> ] | [ B<-6 | --use-ipv6> ] ] [ B<--packets> I<number of packets> ] [ B<--buffersize> I<number of bytes> ] [ B<--timeout> I<seconds> ] [ B<--verbose> .. ] [  B<--help> ]

=head1 DESCRIPTION

Inspired by the standard Nagios plugin check_ping, B<check-winping> performs ping checks from Windows systems. It is a compiled perl script and the source code is available as a part of the package. 

=head1 OPTIONS

=over 4 

=item B<-H|--hostname> I<host>

Hostname to ping. Required.

=item B<--warning> I<threshold>

Return WARNING if measured values are at least the threshold values. A I<threshold> is specified as a combination of round trip time and packet loss ratio with the following format : B<round-trip-time in milliseconds,packet-losss-ratio%>. Example: 100,80%. Required.

=item B<--warning> I<threshold>

Return CRITICAL if measured values are at least the threshold values. A I<threshold> is specified as a combination of round trip time and packet loss ratio with the following format : B<round-trip-time in milliseconds,packet-losss-ratio%>. Example: 100,80%. Required.

=item B<-4|--use-ip4>

Use IPv4 connection (standard Windows ping.exe). Optional. Default is on.

=item B<-6|--use-ip6>

Use IPv6 connection (standard Windows ping6.exe). Optional. Default is off.

=item B<--packets> I<number of packets>

Specify the number of packets to send during pinging. Optional. Default is 5 packets.

=item B<--buffersize> I<number of bytes>

Specify buffer size for ping packets. Optional. Default is 32 bytes.

=item B<--timeout> I<seconds>

Specify ping timeout in seconds. Optional. Default is 10 seconds.

=item B<--verbose>

Produces detailed output for debugging. Optional. Can be specified up to twice for increasing verbosity.

=item B<--help>

Produces a help message.

=back

=head1 EXAMPLE

 check-winping -H itefix.no --warning 100,80% --critical 250,100%

Checks I<itefix.no> with default ping values and returns WARNING if round trip average or packet loss ratio is at least 100 ms or 80% respectively, returns CRITICAL if round trip average or packet loss ratio is at least 250 ms or 100% respectively

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

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License. L<http://www.opensource.org/licenses/artistic-license.php>

=head1 VERSION

Version 1.5, February 2013

=head1 CHANGELOG

=over 4

=item Changes from 1.4

 - Bug fix: Proper handling of no responses.
 - New packaging with a faster binary and no need for local temp storage

=item Changes from 1.3

 - Produce performance data output according to the guidelines

=item Changes from 1.2

 - Bug fix: Newer Windows versions produce ping messages with one less
   empty line. check-winping strips now all empty lines before
   processing ping output.

=item Changes from 1.1

 - Better pattern match for localized pings (support for multiple words)
 - Scan response messages to detect anomalies (TTL expire for instance)

=item Changes from 1.0

 - Use more generalized match patterns to support localized ping/ping6

=item Initial version

=back

=cut