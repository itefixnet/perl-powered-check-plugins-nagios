#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-winservice.pl - Nagios compatible check plugin for Windows services

use strict;
use warnings;
use Getopt::Long;
use Win32;
use Win32::OLE qw( in );
use Digest::MD5 qw(md5_hex);

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

our @state = ();
our @startmode = ();
our @service = ();
our $wql = "",
our $fingerprint = undef;
our $drive = undef;
our $warning = undef;
our $critical = undef;
our $verbose = 0;
 
GetOptions (
	"state=s" => \@state,
	"startmode=s" => \@startmode,
	"service=s" => \@service,
	"fingerprint:s" => \$fingerprint,
	"warning=i" => \$warning,
	"critical=i" => \$critical,
	"verbose+" => \$verbose,
	"help" => sub { PrintUsage() },
) or ExitProgram($UNKNOWN, "Usage problem");

# Process comma separated values
@state = split(",", join(',',@state));
@startmode = split(",", join(',',@startmode));
@service = split(/,/, join(',',@service));

# Set defaults for non specified parameters
# state - all, start mode - all, all services - all
(scalar @state) || ($state[0] = 'all');
$verbose && print "Service state(s): " . join(', ', @state) . "\n";

(scalar @startmode) || ($startmode[0] = 'all');
$verbose && print "Service start modes: " . join(', ', @startmode) . "\n";

(scalar @service) || ($service[0] = 'all');
$verbose && print "Service(s): " . join(', ', @service) . "\n";

$wql = "select * from Win32_Service";

if ($service[0] ne 'all')
{
	$wql .= " Where ";
	$wql .= "(" . CreateWql("Name", \@service) . ")";
}

if ($startmode[0] ne 'all')
{
	$wql .= $service[0] eq 'all' ? " Where" : " And" ;
	$wql .= " (" . CreateWql("StartMode", \@startmode) . ")";
}

if ($state[0] ne 'all')
{
	$wql .= ($service[0] eq 'all' && $startmode[0] eq 'all') ? " Where" : " And" ;
	$wql .= " (" . CreateWql("State", \@state) . ")";
}

($verbose > 1) && print "WQL string generated: $wql\n";

my $wmiresult = {'Top' => {} };
WMI(Win32::NodeName(), $wql, $wmiresult->{'Top'}, 'Name');

my $numservices = scalar keys %{$wmiresult->{Top}};
$verbose && print "Number of services selected: $numservices\n";
($verbose > 1) && print "Selected services: " . join(", ", keys %{$wmiresult->{Top}}) . "\n";

if (not defined $fingerprint)
{
	my $result = $OK;	
	defined $warning && ($numservices > $warning) && ($result = $WARNING);
	defined $critical && ($numservices > $critical) && ($result = $CRITICAL);
	
	my $message = "$numservices service(s).|services=$numservices;" .
		((defined $warning ? $warning : "") . ";" . (defined $critical ? $critical : "") . ";");
		
	ExitProgram($result, $message);
} else {

	# Create a fingerprint
	my $snapshot = "";

	foreach my $service (keys %{$wmiresult->{Top}})
	{
		my $hs = $wmiresult->{Top}{$service};
		$snapshot .= $hs->{Name} . $hs->{DisplayName} . $hs->{PathName} . $hs->{ServiceType} . 
			$hs->{Started} . $hs->{StartMode} . $hs->{StartName} . $hs->{State} . $hs->{Status} . 
			$hs->{Description};
	}

	my $snapshot_fingerprint = md5_hex($snapshot);
	$verbose && print "Snapshot fingerprint: " . $snapshot_fingerprint . "\n";
	
	# print only fingerprint if no fingerprint as parameter is specified
	$fingerprint eq "" && ExitProgram($OK, "Service snapshot fingerprint: $snapshot_fingerprint");
		
	my $result = $UNKNOWN;
	my $message = "";
	if ($snapshot_fingerprint eq $fingerprint)
	{
		$result = $OK;
		$message = "Snapshot fingerprint match.";
	} else {
		$result = $CRITICAL;
		$message = "No Snapshot fingerprint match. Possible service configuration change.";	
	}
	
	ExitProgram($result, $message);
}

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
#
sub PrintUsage
{
print "
check-winservice - Nagios compatible check plugin for Windows services
Version $VERSION, Copyright 2011, http://itefix.no

Usage:
    check-winservice [ [ --service service[,service ...] ] ... ] [ [ --state
    state[,state ...] ] ... ] [ [ --startmode startmode[,startmode ...] ]
    ... ] [ --fingerprint [fingerprint] ] [--warning *threshold*]
    [--critical *threshold*] [--verbose] [--help]

Options:
    --service service[,service ...] ] ...
        Specifies services you want to monitor. You can supply comma
        separated values as well as multiple --service options. In addition,
        you may exclude a service by prepending a ! (like !alerter).
        Optional. Defaults to all services.

    --state state[,state ...] ] ...
        Specifies service states you want to monitor. You can supply comma
        separated values as well as multiple --state options. In addition,
        you may negate a state by prepending a ! (like !running). Available
        state values (case insensitive):

         - running
         - stopped
         - paused
         - start pending
         - stop pending
         - continue pending
         - pause pending
         - unknown

        Optional. Defaults to all states.

    --startmode startmode[,startmode ...] ] ...
        Specifies service start modes you want to monitor. You can supply
        comma separated values as well as multiple --startmode options. In
        addition, you may negate a start mode by prepending a ! (like
        !auto). Available start mode values (case insensitive):

         - auto
         - manual
         - disabled
         - boot
         - system

        Optional. Defaults to all start modes.

    --fingerprint [fingerprint]
        Generates a *service snapshot fingerprint* for the selected set of
        services. A *service snapshot fingerprint* is simply an MD5 digest
        of a string consisting of concatenated values of following
        properties for each selected service:

         - Name, DisplayName, PathName, ServiceType, Started, StartMode, StartName, State, Status, Description

        prints the fingerprint if no parameter is specified. Otherwise it
        checks if the given fingerprint matches the current fingerprint for
        the selected services. Returns CRITICAL if it is a mismatch, OK
        otherwise. That way, you can get an indication about a possible
        unauthorized service configuration change.

    --warning *threshold*
        Returns WARNING exit code if the selected number of services is
        above the *threshold*. Optional.

    --critical *threshold*
        Returns CRITICAL exit code if the selected number of services is
        above the *threshold*. Optional.

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
	print "SERVICE $status_text{$exitcode} - $message";
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
		
		foreach my $object (in $pc->{Properties_})
		{	
			if (ref($object->{Value}) eq "ARRAY")
			{
				$result_hash->{$object->{Name}} = [];

				foreach my $value (in($object->{Value}) )
				{
					if ($groupbyvalue)
					{
						push @{$result_hash->{$groupbyvalue}{$object->{Name}}}, $value;
					} else
					{
						push @{$result_hash->{$object->{Name}}}, $value;
					}
				}
			} else 
			{	
				if ($groupbyvalue)
				{
					$result_hash->{$groupbyvalue}{$object->{Name}} = $object->{Value};
				} else
				{
					$result_hash->{$object->{Name}} = $object->{Value};
				}
			}
		}
	}
}

__END__

=head1 NAME

check-winservice - Nagios compatible check plugin for Windows services

=head1 SYNOPSIS

B<check-winservice> [ [ B<--service> service[,service ...] ] ... ] [ [ B<--state> state[,state ...] ] ... ] [ [ B<--startmode> startmode[,startmode ...] ] ... ] [ B<--fingerprint> [fingerprint] ] [B<--warning> I<threshold>] [B<--critical> I<threshold>] [B<--verbose>] [B<--help>]

=head1 DESCRIPTION

B<check-winservice> is a Nagios plugin to monitor services on the local Windows system. You can filter services based on name, state or start mode. Negation is also possible. check-winservice has also a I<service snapshot fingerprint> capability which may help you to monitor changes on service configurations.

=head1 OPTIONS

=over 4

=item B<--service> service[,service ...] ] ...

Specifies services you want to monitor. You can supply comma separated values as well as multiple --service options. In addition, you may exclude a service by prepending a B<!> (like !alerter). Optional. Defaults to all services.

=item B<--state> state[,state ...] ] ...

Specifies service states you want to monitor. You can supply comma separated values as well as multiple --state options. In addition, you may negate a state by prepending a B<!> (like !running). Available state values (case insensitive):

 - running
 - stopped
 - paused
 - start pending
 - stop pending
 - continue pending
 - pause pending
 - unknown

Optional. Defaults to all states.

=item B<--startmode> startmode[,startmode ...] ] ...

Specifies service start modes you want to monitor. You can supply comma separated values as well as multiple --startmode options. In addition, you may negate a start mode by prepending a B<!> (like !auto). Available start mode values (case insensitive):

 - auto
 - manual
 - disabled
 - boot
 - system

Optional. Defaults to all start modes.

=item B<--fingerprint> [fingerprint]

Generates a I<service snapshot fingerprint> for the selected set of services. A I<service snapshot fingerprint> is simply an MD5 digest of a string consisting of concatenated values of following properties for each selected service:

 - Name, DisplayName, PathName, ServiceType, Started, StartMode, StartName, State, Status, Description

prints the fingerprint if no parameter is specified. Otherwise it checks if the given fingerprint matches the current fingerprint for the selected services. Returns CRITICAL if it is a mismatch, OK otherwise. That way, you can get an indication about a possible unauthorized service configuration change.

=item B<--warning> I<threshold>

Returns WARNING exit code if the selected number of services is above the I<threshold>. Optional.

=item B<--critical> I<threshold>

Returns CRITICAL exit code if the selected number of services is above the I<threshold>. Optional.

=item B<--verbose>

Produces some output for debugging or to see individual values of samples. Multiple values are allowed.

=item B<--help>

Produces a help message.

=back

=head1 EXAMPLES

 check-winservice --startmode auto --state !running --critical 0

Returns CRITICAL if there exists automatic services which are not running.


 check-winservice --service TroubleMaker1,TroubleMaker2 --state running --critical 0

Returns CRITICAL if services I<TroubleMaker1> or I<TroubleMaker2> are running.


 check-winservice --critical 1 -startmode boot,system -service !BootA,!BootB,!SystemC

Returns CRITICAL if there is at least one service except service BootA, BootB and SystemC, which is configured to start during boot or system phase.


 check-winservice --warning 200 --critical 300

Returns WARNING or CRITICAL if the number of defined services exceeds 200 or 300 respectively.


 check-winservice --startmode !manual --service Manual1,Manual2 --service Manual3 --critical 0

Returns CRITICAL if services I<Manual1>, I<Manual2> or I<Manual3> are not configured to run manually.


 check-winservice --fingerprint --state running

Print the I<service snapshot fingerprint> for running services.


 check-winservice --fingerprint xxxxxxxxxxxxxxxxxxxxxxx --state running

Returns CRITICAL if the specified fingerprint xxxxxxx does not match the I<service snapshot fingerprint> of running services


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

=item typeperf documentation L<http://www.microsoft.com/resources/documentation/windows/xp/all/proddocs/en-us/nt_command_typeperf.mspx?mfr=true>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License. L<http://www.opensource.org/licenses/artistic-license.php>

=head1 VERSION

Version 1.1, October 2011

=head1 CHANGELOG

=over 4

=item Changes from 1.0

 - Bug fix: Improper combination of multiple negated elements in the generated WQL string.

=item Initial release

=back

=cut