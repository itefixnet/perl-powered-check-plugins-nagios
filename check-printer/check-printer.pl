#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-printer.pl - Nagios compatible check plugin for printer checks
#
# Requirement: Net-SNMP

use strict;
use warnings;
use Getopt::Long;

our $VERSION = "1.1";

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

our $DEFAULT_COMMUNITY = "public";

our $PTR_CONSOLE_DISPLAY_BUFFER_TEXT =	".1.3.6.1.2.1.43.16";
our $PTR_ALERT_TABLE =					".1.3.6.1.2.1.43.18";
our $PTR_ALERT_INDEX =					".1.3.6.1.2.1.43.18.1.1.1.1";
our $PTR_ALERT_SEVERITY_LEVEL =			".1.3.6.1.2.1.43.18.1.1.2.1";
our $PTR_ALERT_TRAINING_LEVEL = 		".1.3.6.1.2.1.43.18.1.1.3.1";
our $PTR_ALERT_GROUP =					".1.3.6.1.2.1.43.18.1.1.4.1";
our $PTR_ALERT_GROUP_INDEX = 			".1.3.6.1.2.1.43.18.1.1.5.1";
our $PTR_ALERT_LOCATION	=				".1.3.6.1.2.1.43.18.1.1.6.1";
our $PTR_ALERT_CODE	=					".1.3.6.1.2.1.43.18.1.1.7.1";
our $PTR_ALERT_DESCRIPTION =			".1.3.6.1.2.1.43.18.1.1.8.1";
our $PTR_ALERT_TIME	=					".1.3.6.1.2.1.43.18.1.1.9.1";

our $LEVEL_UNTRAINED = 3;
our $LEVEL_TRAINED = 4;
our $LEVEL_FIELDSERVICE = 5;

our %code_mask = ( #  specify mask for binary change events which be should considered critical 
				#  other(1) 
			    #  unknown(2) 
			    #  coverOpen(3) 
			    #  coverClosed(4) 
			    #  interlockOpen(5) 
			    #  interlockClosed(6) 
			    #  configurationChange(7) 
    8 => 1,		#  jam(8) 
    9 => 1,		#  subunitMissing(9) 			-- Not in RFC 1759 
				#  subunitLifeAlmostOver(10)		-- Not in RFC 1759 
    11 => 1,	#  subunitLifeOver(11)			-- Not in RFC 1759 
				#  subunitAlmostEmpty(12)		-- Not in RFC 1759 
    13 => 1,	#  subunitEmpty(13)			-- Not in RFC 1759 
				#  subunitAlmostFull(14)		-- Not in RFC 1759 
				#  subunitFull(15)			-- Not in RFC 1759 
				#  subunitNearLimit(16)			-- Not in RFC 1759 
			    #  subunitAtLimit(17)			-- Not in RFC 1759 
			    #  subunitOpened(18)			-- Not in RFC 1759 
			    #  subunitClosed(19)			-- Not in RFC 1759 
			    #  subunitTurnedOn(20)			-- Not in RFC 1759 
    21 => 1,	#  subunitTurnedOff(21)			-- Not in RFC 1759 
    22 => 1,	#  subunitOffline(22)			-- Not in RFC 1759 
			    #  subunitPowerSaver(23)		-- Not in RFC 1759 
			    #  subunitWarmingUp(24)			-- Not in RFC 1759 
			    #  subunitAdded(25)			-- Not in RFC 1759 
    26 => 1,	#  subunitRemoved(26)			-- Not in RFC 1759 
			    #  subunitResourceAdded(27)		-- Not in RFC 1759 
    28 => 1,	#  subunitResourceRemoved(28)		-- Not in RFC 1759 
				#  subunitRecoverableFailure(29)	-- Not in RFC 1759 
    30 => 1,	#  subunitUnrecoverableFailure(30)	-- Not in RFC 1759 
          		#  subunitRecoverableStorageError(31)	-- Not in RFC 1759 
    32 => 1,	#  subunitUnrecoverableStorageError(32)	-- Not in RFC 1759 
	33 => 1,	#  subunitMotorFailure(33)		-- Not in RFC 1759 
	34 => 1,	#  subunitMemoryExhausted(34)		-- Not in RFC 1759 
				#  subunitUnderTemperature(35)		-- Not in RFC 1759 
				#  subunitOverTemperature(36)		-- Not in RFC 1759 
				#  subunitTimingFailure(37)		-- Not in RFC 1759 
				#  subunitThermistorFailure(38)		-- Not in RFC 1759 

				#  doorOpen(501)			-- DEPRECATED - Use coverOpened(3) 
				#  doorClosed(502)  			-- DEPRECATED - Use coverClosed(4) 
				#  powerUp(503) 
				#  powerDown(504) 
				#  printerNMSReset(505)			-- Not in RFC 1759 
				#  printerManualReset(506)		-- Not in RFC 1759 
				#  printerReadyToPrint(507)		-- Not in RFC 1759 

	801 => 1,	#  inputMediaTrayMissing(801) 
				#  inputMediaSizeChange(802) 
				#  inputMediaWeightChange(803) 
				#  inputMediaTypeChange(804) 
				#  inputMediaColorChange(805) 
				#  inputMediaFormPartsChange(806) 
				#  inputMediaSupplyLow(807) 
	808 => 1,	#  inputMediaSupplyEmpty(808) 
				#  inputMediaChangeRequest(809)		-- Not in RFC 1759 
				#  inputManualInputRequest(810)		-- Not in RFC 1759 
				#  inputTrayPositionFailure(811)	-- Not in RFC 1759 
				#  inputCannotFeedSizeSelected(813)	-- Not in RFC 1759 
				#  inputTrayElevationFailure(812)	-- Not in RFC 1759 

	901 => 1,	#  outputMediaTrayMissing(901) 
				#  outputMediaTrayAlmostFull(902) 
	903 => 1,	#  outputMediaTrayFull(903) 
				#  outputMailboxSelectFailure(904)	-- Not in RFC 1759 

				#  markerFuserUnderTemperature(1001) 
				#  markerFuserOverTemperature(1002) 
				#  markerFuserTimingFailure(1003)	-- Not in RFC 1759 
				#  markerFuserThermistorFailure(1004)	-- Not in RFC 1759 
				#  markerAdjustingPrintQuality(1005)	-- Not in RFC 1759 
	1101 => 1,	#  markerTonerEmpty(1101) 
	1102 => 1,	#  markerInkEmpty(1102) 
				#  markerPrintRibbonEmpty(1103) 
				#  markerTonerAlmostEmpty(1104) 
				#  markerInkAlmostEmpty(1105) 
				#  markerPrintRibbonAlmostEmpty(1106) 
				#  markerWasteTonerReceptacleAlmostFull(1107) 
				#  markerWasteInkReceptacleAlmostFull(1108) 
				#  markerWasteTonerReceptacleFull(1109) 
				#  markerWasteInkReceptacleFull(1110) 
				#  markerOpcLifeAlmostOver(1111) 
	1112 => 1,	#  markerOpcLifeOver(1112) 
				#  markerDeveloperAlmostEmpty(1113) 
	1114 => 1,	#  markerDeveloperEmpty(1114) 
	1115 => 1,	#  markerTonerCartridgeMissing(1115)	-- Not in RFC 1759 

	1301 => 1,	#  mediaPathMediaTrayMissing(1301) 
				#  mediaPathMediaTrayAlmostFull(1302) 
	1303 => 1,	#  mediaPathMediaTrayFull(1303) 
				#  mediaPathCannotDuplexMediaSelected(1304) -- Not in RFC 1759 
				#  interpreterMemoryIncrease(1501) 
				#  interpreterMemoryDecrease(1502) 
				#  interpreterCartridgeAdded(1503) 
				#  interpreterCartridgeDeleted(1504) 
				#  interpreterResourceAdded(1505) 
				#  interpreterResourceDeleted(1506) 
				#  interpreterResourceUnavailable(1507) 
				#  interpreterComplexPageEncountered(1509) -- Not in RFC 1759 
				#  alertRemovalOfBinaryChangeEntry(1801) -- Not in RFC 1759 
);

our $training_level = $LEVEL_TRAINED;

our $hostname = undef;
our $community = $DEFAULT_COMMUNITY;
our $verbose = 0;
our $snmpwalk_path = "snmpwalk";

GetOptions (
	"host|H=s" => \$hostname,
	"community|c=s" => \$community,
	"snmpwalk=s" => \$snmpwalk_path,
	"verbose+" => \$verbose,
	"help" => sub { PrintUsage() },
) or ExitProgram($UNKNOWN, "Usage problem");

$hostname || ExitProgram($UNKNOWN, "Usage problem, hostname parameter is required");
our $snmpwalk_command = "\"$snmpwalk_path\" -On -Oe -Oq -Oa -v1 -c $community $hostname $PTR_ALERT_TABLE";
print "Snmpwalk command: $snmpwalk_command\n" if $verbose;

# Run command
open SNMPWALK_OUTPUT, "$snmpwalk_command |" or ExitProgram($UNKNOWN, $!);

our $snmpwalk_output = undef;
our %snmpwalk_entry = ();
my $state = $UNKNOWN;
my $message = "";

while (<SNMPWALK_OUTPUT>)
#while (<STDIN>) # parse test
{
	print if $verbose;
	chomp;
	$snmpwalk_output = $_;
	
	my ($index, $value) = ($snmpwalk_output =~ /.1.3.6.1.2.1.43.18.1.1.\d+.1.(\d+) (.*)/);
	
	if ($snmpwalk_output =~ /$PTR_ALERT_SEVERITY_LEVEL/)
	{
		$snmpwalk_entry{$index}{severity} = $value;
		
	} elsif ($snmpwalk_output =~ /$PTR_ALERT_TRAINING_LEVEL/)
	{
		$snmpwalk_entry{$index}{training} = $value;
		
	} elsif ($snmpwalk_output =~ /$PTR_ALERT_CODE/)
	{
		 $snmpwalk_entry{$index}{code} = $value;
		 
	} elsif ($snmpwalk_output =~ /$PTR_ALERT_DESCRIPTION/)
	{
		$snmpwalk_entry{$index}{description} = $value;
	
	} elsif (not ($snmpwalk_output =~ /$PTR_ALERT_TABLE/))
	{
		# AlertDescription is hex and more than one line
		$snmpwalk_entry{$index}{description} .= $value;
	}

	foreach my $line (keys %snmpwalk_entry)
	{
		if ($verbose)
		{
			print 
			"  ==> line=$line, severity=" . $snmpwalk_entry{$line}{severity} . 
			", training=" . $snmpwalk_entry{$line}{training} .
			"=> " . $snmpwalk_entry{$line}{description} . "\n";
		}
		
		$message = $snmpwalk_entry{$line}{description};
		
		# only care for states which require intervention of service personal
		if ($training_level <= $snmpwalk_entry{$line}{training} && $snmpwalk_entry{$line}{training} <= $LEVEL_FIELDSERVICE) {

			# use the last (latest?) AlarmTableEntry with the highest priority
			my $severity = $snmpwalk_entry{$line}{severity};
			
			if ($severity == 1)
			{
				$state = $OK if $state == $UNKNOWN; # other
				
			} elsif ($severity == 3) # critical
			{
				$state = $CRITICAL;
			
			} elsif ($severity == 4) # warning
			{
				$state = $WARNING if ($state == $OK || $state == $UNKNOWN)
				
			} elsif ($severity == 5) # warningBinaryChangeEvent -- New, not in RFC 1759
			{
				$state = $WARNING if ($state == $OK || $state == $UNKNOWN);				
				$state = $CRITICAL if defined $code_mask{$snmpwalk_entry{$index}{code}};				
			}

			$state = $OK if $state == $UNKNOWN;
		}
	}	

}

close SNMPWALK_OUTPUT;

ExitProgram($state, $message);

#### SUBROUTINES ####

##### PrintUsage #####
#
sub PrintUsage
{
print "
Usage:
    check-printer --host|H printer [ --community|c snmp-community ] [
    --snmpwalk snmpwalk-path ] [--verbose] [--help]

Options:
    --host|H printer
        Specifies printer *hostname/ip-address* to monitor. Required.

    --community|c snmp community
        Specifies SNMP community name. Default value is 'public'.

    --snmpwalk snmpwalk-path
        Specifies path to the snmpwalk program. Default value is 'snmpwalk'

    --verbose
        Produces detailed output for debugging

    --help
        Produces a help message.

";

exit 0;

}

##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;	
	print "$status_text{$exitcode} - $message";
	exit ($exitcode);
}


__END__

=head1 NAME

check-printer - Nagios plugin for printer health via SNMP

=head1 SYNOPSIS

B<check-printer> B<--host|H> printer [ B<--community|c> snmp-community ] [ B<--snmpwalk> snmpwalk-path ] [B<--verbose>] [B<--help>]

=head1 DESCRIPTION

B<check-printer> is a Nagios plugin to monitor printer health via SNMP. It uses snmpwalk command to retrieve printer alert table. Strongly inspired by check-printers plugin http://exchange.nagios.org/directory/Plugins/Network-Protocols/SNMP/check-printers/details

=head1 OPTIONS

=over 4

=item B<--host|H> printer

Specifies printer I<hostname/ip-address> to monitor. Required.

=item B<--community|c> snmp community

Specifies SNMP community name. Default value is 'public'.

=item B<--snmpwalk> snmpwalk-path

Specifies path to the snmpwalk program. Default value is 'snmpwalk'

=item B<--verbose>

Produces detailed output for debugging

=item B<--help>

Produces a help message.

=back

=head1 EXAMPLES

 check-printer --host 10.0.0.100

Retrieves alert table from the printer and produces status output.

 check-printer --host 10.0.0.100 --snmpwalk "c:\util\netsnmp\bin\snmpwalk"

Retrieves alert table from the printer via snmpwalk binary c:\util\netsnmp\bin\snmpwalk and produces status output.

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

=item check-printers plugin - L<http://exchange.nagios.org/directory/Plugins/Network-Protocols/SNMP/check-printers/details/>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License L<http://www.opensource.org/licenses/artistic-license.php/>

=head1 VERSION

Version 1.1, December 2023

=head1 CHANGELOG

=over 4

=item Changes from 1.0

 - code clean-up
 
=item Initial release

=back

=cut