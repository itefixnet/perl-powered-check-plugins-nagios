#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-wmic.pl - Nagios compatible check plugin for WMI checks
#
# Requirement: WMIC.EXE
#

use strict;
use Getopt::Long;
use Win32;

our $VERSION = "1.2";

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

our $warning = undef;
our $critical = undef;
our $hostname = undef;
our $verbose = 0;
our $user = undef;
our $password = undef;
our $alias = undef;
our $property = undef;
our $ratio = undef;
our $every = undef;
our $repeat = undef;
our $format = undef;
our $factor = undef;
our $compare = 'gt'; # type of comparison operator for critical/warning thresholds (gt, eq, lt)
our $count = 0;

GetOptions (
	"warning=f" => \$warning,
	"critical=f" => \$critical,
	"compare=s" => sub { $compare = lc $_[1] },
	"host|H=s" => \$hostname,
	"user=s" => \$user,
	"password=s" => \$password,
	"alias=s" => \$alias,
	"property=s" => \$property,
	"ratio=s" => \$ratio,
	"repeat=i" => \$repeat,
	"every=i" => \$every,
	"format=s" => \$format,
	"factor=f" => \$factor,
	"count" => \$count,
	"verbose+" => \$verbose,
	"help" => sub { PrintUsage() },
) or ExitProgram($UNKNOWN, "Usage problem");

($alias && $property) || ExitProgram($UNKNOWN, "Alias and property are required parameters.");
grep (/$compare/, split (',', 'eq,ne,gt,ge,lt,le')) || ExitProgram($UNKNOWN, "Unsupported compare operator: $compare");

# Preparing wmic command
my $wmic = "WMIC";

$wmic .= " /NODE:$hostname" if $hostname;
$wmic .= " /USER:$user" if $user;
$wmic .= " /PASSWORD:$password" if $password;

$wmic .= " $alias GET $property";
$wmic .= ",$ratio" if $ratio;
$wmic .= " /EVERY:$every /REPEAT:$repeat" if $every && $repeat;

print "WMIC command: $wmic\n" if $verbose;

# Run command
open WMIC_OUTPUT, "$wmic |" or ExitProgram($UNKNOWN, $!);

my $obs_count = 0;
my $obs_number = 0;
my $obs_sum = 0;
my $ratio_sum = 0;
my $obs_value = undef;
my $ratio_value = undef;
my $line = undef;
my $obs_host = $hostname || Win32::NodeName;

while (<WMIC_OUTPUT>)
{
	
	if ($ratio) # we have two values in a line if ratio is specified
	{
        ($obs_value, $ratio_value) = split /\s+/;
	} else {
		($obs_value) = split /\s+/;
	}

	(defined $obs_value && $obs_value ne '') || next;
	next if lc $property eq lc $obs_value; # Remove property title
	
	$obs_number++;
	
	# If multiple observations, drop the first one as it may be highly influenced by a initial warm-up
	if ($repeat > 1 && $obs_number == 1)
	{
		print "First observation value $obs_value is ignored as it may be highly influenced by a initial warm-up.\n" if $verbose;
		next;
	}
	
	# value sum is relevant if count is not defined
	$count || ($obs_sum += $obs_value) && (defined $ratio && ($ratio_sum += $ratio_value));
	
	$obs_count++;
	
    print "Observation $obs_count - $obs_value" . ($ratio ? ", $ratio_value" : "") . "\n" if $verbose;

}

close WMIC_OUTPUT;

if ($count)
{
    $obs_value = $obs_count;
} else {
    $obs_count || ExitProgram($UNKNOWN, "No observations.");
    
    $obs_sum /= $ratio_sum if ($ratio && $ratio_sum); # create ratio
    $obs_value = $obs_sum / $obs_count;     
}

$obs_value *= $factor if defined $factor && $factor; # factoring

$obs_value *= 100 if $ratio;

my $results = (defined $format) ? sprintf($format, $obs_value, $obs_value) : $obs_value;

my $state = $OK;
defined $warning && IsThreshold($obs_value, $warning, $compare) && ($state = $WARNING);
defined $critical && IsThreshold($obs_value, $critical, $compare) && ($state = $CRITICAL);
	
ExitProgram($state, $results);

#### SUBROUTINES ####

##### PrintUsage #####
#
sub PrintUsage
{
print <<USAGE;
Usage:
    check-wmic --host|H hostname [ --user user --password password ] --alias
    alias --property property [ --every interval --repeat count ] [ --format
    output-format ] [ --factor number ] [--count] [ --ratio property ] [
    --compare operator ] [--warning *threshold*] [--critical *threshold*]
    [--verbose] [--help]

Options:
    --host|H hostname
        Specifies remote *hostname/ip-address* to monitor. Required.

    --user user --password password
        Specifies credentials to be used to initiate a WMI-connection to the
        remote host. Optional. Credentials of the user running the plugin
        are used as default.

    --alias alias --property property
        Specifies WMI-alias and -property to process in the plugin. Running
        ""wmic /?"" produces available aliases on a system. More information
        about the alias and supported properties are available via ""wmic
        alias" *alias name*". Please check wmic and wql documentation for
        more details.

        Some simple alias and property examples:

         CPU, LoadPercentage
         OS, FreePhysicalMemory
         PAGEFILE, CurrentUsage

        or a complex one:

         Service where (StartMode='Auto' And State!='Running'),Name

        Alias and property are required values.

    --every interval --repeat count
        check-wmic allows you to use wmic options EVERY (in seconds) and
        REPEAT to collect multiple measurements of the same property value.
        Those can be used to calculate an average value for a stretch of
        time, instead of an instant value. CPU Load is a typical example.
        It's been observed that a first measurement in this scenario may
        deviate greatly from other values, due to a potential initial
        warm-up overhead. check-wmic ignores simply the first observation
        due to that fact.

    --format output-format
        It's often desirable to produce some descriptive text as a part of
        the plugin. Describing measured value, measurement units or Nagios
        performance data are examples. --format option allows you to specify
        a format which is acceptable as a first argument to Perl's sprintf
        function. You can specify up to 2 conversions for the value
        collected, one for the normal output, and the other for the
        performance data. Optional.

        Example 1: Collected data: 65, format CPU Load: %d%|'cpu load'=%d%
        produces ""CPU Load: 65%|'cpu load'=65%"".

        Example 2: Collected data: 12.45678934, Format Free memory: %.2f MB.
        produces ""Free memory: 12.46 MB."".

    --factor number
        Sometimes it may be necessary to convert values into more meaningful
        units. *Bytes to MB* or *bits to Mbits* are typical examples. Option
        --factor can be used to multiply the value with the factor you
        specify. Example: factor *0,0009765625* can be used to convert KB to
        MB, MB to GB ...

    --count number
        Some properties generate a list of items instead of a single value.
        List of services is an example. Option --count instructs the plugin
        to count the collected values, not processing them individually.
        Optional.

    --ratio property
        Specify one additional property to be used for calculaction of a
        ratio. Example "--property FreeSpace --ratio Size" allows the plugin
        to work on ratio values of "FreeSpace/Size".

    --compare *operator*
        Specify the type of comparison operator for threshold checks.
        Optional. Available values are:

         'eq'  equal to
         'ne'  not equal
         'gt'  greater than (default!)
         'ge'  greater or equal
         'lt'  less than
         'le'  less or equal

    --warning *threshold*
        Returns WARNING exit code if the value is above (if the warning
        threshold lower than the critical one) or below the *threshold*.
        Optional.

    --critical *threshold*
        Returns CRITICAL exit code if the value is above (if the warning
        threshold lower than the critical one) or below the *threshold*.
        Optional.

    --verbose
        Produces some output for debugging or to see individual values of
        samples.

    --help
        Produces a help message.
        
USAGE

}

##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;	
	print "$status_text{$exitcode} - $message";
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

check-wmic - Nagios compatible check plugin for WMI checks

=head1 SYNOPSIS

B<check-wmic> B<--host|H> hostname [ B<--user> user B<--password> password ] B<--alias> alias B<--property> property [ B<--every> interval B<--repeat> count ] [ B<--format> output-format ] [ B<--factor> number ] [B<--count>] [ B<--ratio> property ] [ B<--compare> operator ] [B<--warning> I<threshold>] [B<--critical> I<threshold>] [B<--verbose>] [B<--help>]

=head1 DESCRIPTION

B<check-wmic> is a Nagios plugin to monitor Windows systems via WMI (Windows Management Instrumentation) from Windows. It uses command line tool WMIC, available as standard from Windows XP/2003 on. B<check_wmi> can be used as an Windows NRPE plugin as well as an agentless monitoring solution for Nagwin.

=head1 OPTIONS

=over 4

=item B<--host|H> hostname

Specifies remote I<hostname/ip-address> to monitor. Required.

=item B<--user> user B<--password> password

Specifies credentials to be used to initiate a WMI-connection to the remote host. Optional. Credentials of the user running the plugin are used as default.

=item B<--alias> alias B<--property> property

Specifies WMI-alias and -property to process in the plugin. Running "C<wmic /?>" produces available aliases on a system. More information about the alias and supported properties are available via "C<wmic alias> I<alias name>". Please check wmic and wql documentation for more details.

Some simple alias and property examples:

 CPU, LoadPercentage
 OS, FreePhysicalMemory
 PAGEFILE, CurrentUsage

or a complex one:

 Service where (StartMode='Auto' And State!='Running'),Name

Alias and property are required values.

=item B<--every> interval B<--repeat> count

B<check-wmic> allows you to use wmic options B<EVERY> (in seconds) and B<REPEAT> to collect multiple measurements of the same property value. Those can be used to calculate an average value for a stretch of time, instead of an instant value. CPU Load is a typical example. It's been observed that a first measurement in this scenario may deviate greatly from other values, due to a potential initial warm-up overhead. B<check-wmic> ignores simply the first observation due to that fact.

=item B<--format> output-format

It's often desirable to produce some descriptive text as a part of the plugin. Describing measured value, measurement units or Nagios performance data are examples. B<--format> option allows you to specify a format which is acceptable as a first argument to Perl's sprintf function. You can specify up to 2 conversions for the value collected, one for the normal output, and the other for the performance data. Optional.

Example 1: Collected data: B<65>, format B<CPU Load: %d%|'cpu load'=%d%> produces "C<CPU Load: 65%|'cpu load'=65%>".

Example 2: Collected data: B<12.45678934>, Format B<Free memory: %.2f MB.> produces "C<Free memory: 12.46 MB.>".

=item B<--factor> number

Sometimes it may be necessary to convert values into more meaningful units. I<Bytes to MB> or I<bits to Mbits> are typical examples. Option B<--factor> can be used to multiply the value with the factor you specify. Example: factor I<0,0009765625> can be used to convert KB to MB, MB to GB ...

=item B<--count> number

Some properties generate a list of items instead of a single value. List of services is an example. Option B<--count> instructs the plugin to count the collected values, not processing them individually. Optional.

=item B<--ratio> property

Specify one additional property to be used for calculaction of a ratio. Example "--property FreeSpace --ratio Size" allows the plugin to work on ratio values of "FreeSpace/Size".

=item B<--compare> I<operator>

Specify the type of comparison operator for threshold checks. Optional. Available values are:

 'eq'  equal to
 'ne'  not equal
 'gt'  greater than (default!)
 'ge'  greater or equal
 'lt'  less than
 'le'  less or equal

=item B<--warning> I<threshold>

Returns WARNING exit code if the value is above (if the warning threshold lower than the critical one) or below the I<threshold>. Optional.

=item B<--critical> I<threshold>

Returns CRITICAL exit code if the value is above (if the warning threshold lower than the critical one) or below the I<threshold>. Optional.

=item B<--verbose>

Produces some output for debugging or to see individual values of samples.

=item B<--help>

Produces a help message.

=back

=head1 EXAMPLES

 check-wmic --host 10.0.0.100 --user abra --password kadabra --alias cpu --property LoadPercentage --every 4 --repeat 4 --format "CPU load %.2f%.|'CPU Load'=%.2f%" --warning 75 --critical 90

Connects to the host by the supplied credentials, collects CPU load percentage three times (the first one of four is dropped) with 4-secs intervals, calculates an average value, and produces an output according to the format specified. Returns CRITICAL if the load is more than 90%, WARNING if it is more than 75%.

 check-wmic --host 10.0.0.100 --alias "LogicalDisk where DeviceID='C:'" --property FreeSpace --factor 0.0000009536743 --format "Free disk space on C: %.2f MB|'Free C:'=%.2fMB" --warn 500 --crit 50

Connects to the host by the current user's credentials, collects free space available on C-disk in bytes, converts it to MB by using the factor specified, and produces an output according to the format specified. Returns CRITICAL if free space is under 50 MB, WARNING if it is under 500 MB.

 check-wmic --host 10.0.0.100 --alias "LogicalDisk where DeviceID='C:'" --property FreeSpace --Ratio Size --format "Free disk space on C: %.2f% |'Free C:'=%.2f%" --warn 2 --critical 0.5 --compare lt

Connects to the host by the current user's credentials, collects free space and size on C-disk in bytes, calculates free space ratio (freespace/size), and produces an output according to the format specified. Returns WARNING if free space is less than 2%, CRITICAL if it is less than 0.5%.

 check-wmic --host 10.0.0.100 --user 'abra@nuke.local' --password '!!"#%&' --alias "Service where (StartMode='Auto' And State!='Running')" --property Name --count --format "%d non-running automatic services." --crit 5

Connects to the host by the supplied domain account credentials, collects the instances of automatic Windows services which are not running, counts them, and produces an output according to the format specified. Returns CRITICAL if there are at least 5 such services.

=head1 EXIT VALUES

 0 OK
 1 WARNING
 2 CRITICAL
 3 UNKNOWN

=head1 AUTHOR

Tevfik Karagulle L<http://www.itefix.net>

=head1 SEE ALSO

=over 4

=item Nagios web site - L<http://www.nagios.org/>

=item WMIC Tool - L<http://msdn.microsoft.com/en-us/library/windows/desktop/aa394531%28v=vs.85%29.aspx/>

=item Perl sprintf - L<http://perldoc.perl.org/functions/sprintf.html/>

=item WQL (SQL for WMI) - L<http://msdn.microsoft.com/en-us/library/windows/desktop/aa394606%28v=vs.85%29.aspx/>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License L<http://www.opensource.org/licenses/artistic-license.php/>

=head1 VERSION

Version 1.2, January 2015

=head1 CHANGELOG

=over 4

=item changes from 1.1

 Add option I<--ratio> to specify one additional property for ratio calculation.
 Options --warning and --critical accept floating values

=item changes from 1.0

 Add option I<--compare> to specify the type of comparison for threshold checks.
 Return unknown if counter is not available.

=item Initial release

