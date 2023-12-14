#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-winad.pl - Nagios compatible check plugin for basic Active Directory health checks
#
# Requirement: DCDIAG.EXE, DSQUERY.EXE

use strict;
use warnings;
use Getopt::Long;
use Win32;
use Win32::OLE;
use Config::IniFiles;
use FindBin qw ($Bin);

our $VERSION = "1.8";

# check-winad configuration file
our $config = "$Bin/check-winad.config";
our $SECTION_LANGUAGE = "Language";

# standard set of language mappings, english is default
my %language = (
	"dcdiag_connectivity" 		=> "passed test connectivity",
	"dcdiag_services" 			=> "passed test services",
	"dcdiag_replications"		=> "passed test replications",
	"dcdiag_advertising"		=> "passed test advertising",
	"dcdiag_fsmo"				=> "passed test fsmocheck",
	"dcdiag_rid"				=> "passed test ridmanager",
	"dcdiag_machine"			=> "passed test machineaccount",
	"dcdiag_frssysvol"			=> "passed test frssysvol",
	"dcdiag_sysvolcheck"		=> "passed test sysvolcheck",
	"dcdiag_frsevent"			=> "passed test frsevent",
	"dcdiag_kccevent"			=> "passed test kccevent",
	"dcdiag_dfsrevent"			=> "passed test dfsrevent",
	"dcdiag_warning"			=> "warning",
	"dcdiag_failed"				=> "failed",
);

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

# primary groups of domain controllers
our $RODC_PRIMARYGROUP = 521;
our $RWDC_PRIMARYGROUP = 516;

our $verbose = 0;
our $dc = 0;
our $help = 0;
our $dfsr = 0;
our $eventlog = 1; # take kccevent/frsevent into test set

GetOptions (
	"configfile=s"	=> \$config,
	"dc"   => \$dc,
	"dfsr!" => \$dfsr,
	"eventlog!" => \$eventlog,
	"verbose!" => \$verbose,
	"help" => \$help
) || PrintUsage();

# Check configuration file
if (-e $config)
{
	print "Configuration file $config is found. Processing ..\n" if $verbose;

	my $cf = new Config::IniFiles( -file => $config, -nocase => 1 );
	
	# update language mappings
	foreach my $lfield ($cf->Parameters($SECTION_LANGUAGE))
	{
		my $lprop = $cf->val($SECTION_LANGUAGE, $lfield);
		print "Language mapping update: $lfield = $lprop\n" if $verbose;
		$language{$lfield} = lc $lprop;
	}
}

our ($ver_string, $ver_major, $ver_minor, $ver_build, $ver_id) = Win32::GetOSVersion();
$verbose && print "Operating system is " . "$ver_string - ($ver_id.$ver_major.$ver_minor.$ver_build)\n";

our $is2000 = ($ver_major == 5) && ($ver_minor == 0);
our $is2003 = ($ver_major == 5) && ($ver_minor == 2); # win2003, win2003r2, win home server
our $is2008 = ($ver_major == 6) && (($ver_minor == 0) || ($ver_minor == 1)); # 1 - win2008, 2 - win2008r2
our $is2012 = ($ver_major == 6) && ($ver_minor == 2); # win 2012

# Form dcdiag command arguments
our $dcdiagcmd = "dcdiag /test:services /test:replications /test:advertising /test:fsmocheck /test:machineaccount";

# add sysvol replication checks
my $sysvolchk = "";
$is2003 && ($sysvolchk = " /test:frssysvol");
($is2008 || $is2012) && ($sysvolchk = " /test:sysvolcheck");
$dcdiagcmd .= $sysvolchk;

# check if DC is a RODC (no ridmanager test for RODC)
my $isrodc = 0;

if ($is2008 || $is2012)
{
	my $dcname = Win32::NodeName();
	my $dcdn = `dsquery computer -name $dcname`;
	chomp ($dcdn);
	my $dcquery = `dsquery * $dcdn -attr PrimaryGroupId`;
	$isrodc = ($dcquery =~ /$RODC_PRIMARYGROUP/) ? 1 : 0;
	$verbose && print "Computer $dcname is a " . ($isrodc ? "Read-Only DC" : "Read-Write DC") . "\n";
}

$dcdiagcmd .= " /test:ridmanager" if not $isrodc;

# add eventlog tests if requested
if ($eventlog)
{
	$is2000 && ($dcdiagcmd .= " /test:kccevent");
	$is2003 && ($dcdiagcmd .= " /test:frsevent /test:kccevent");
	($is2008 || $is2012) && (not $dfsr) && ($dcdiagcmd .= " /test:frsevent /test:kccevent");
	($is2008 || $is2012) && $dfsr && ($dcdiagcmd .= " /test:dfsrevent /test:kccevent");
}

$dc && DcTests();
$help && PrintUsage();

#### SUBROUTINES ####

##### DcTests #####
sub DcTests
{

	$verbose && print "Dcdiag command to run: $dcdiagcmd\n";
	
	my $dcdiag_result = `$dcdiagcmd`;
	my @dcdiag_result_original = split (/\n/, $dcdiag_result);
	my @dcdiag_warning = map {$_ if /$language{'dcdiag_warning'}/} @dcdiag_result_original;
	chomp (@dcdiag_warning);
	my @dcdiag_failed = map {$_ if /$language{'dcdiag_failed'}/} @dcdiag_result_original;
	chomp (@dcdiag_failed);
	
	$dcdiag_result = lc $dcdiag_result;
	$dcdiag_result =~s/\n/ /g;

	my ($connectivity, $services, $replications, $advertising, $fsmo, $rid, $machine, $frssysvol, $frsevent, $kccevent, $sysvolcheck, $dfsrevent) = 
		(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

	my $warning = (scalar @dcdiag_warning) ? (join(',', @dcdiag_warning)) : undef;
	$warning =~ s/[\.,\s]{2,}/ /g;
	my $failed = (scalar @dcdiag_failed) ? (join(',', @dcdiag_failed)) : undef;
	$failed =~ s/[\.,\s]{2,}/ /g;
	
	$connectivity 	= 1 if $dcdiag_result =~ /$language{'dcdiag_connectivity'}/;
	$services	  	= 1 if $dcdiag_result =~ /$language{'dcdiag_services'}/;
	$replications	= 1 if $dcdiag_result =~ /$language{'dcdiag_replications'}/;
	$advertising	= 1 if $dcdiag_result =~ /$language{'dcdiag_advertising'}/;
	$fsmo	 		= 1 if $dcdiag_result =~ /$language{'dcdiag_fsmo'}/;
	$rid 			= 1 if $dcdiag_result =~ /$language{'dcdiag_rid'}/;
	$machine 		= 1 if $dcdiag_result =~ /$language{'dcdiag_machine'}/;
	$frssysvol 		= 1 if $dcdiag_result =~ /$language{'dcdiag_frssysvol'}/;
	$sysvolcheck	= 1 if $dcdiag_result =~ /$language{'dcdiag_sysvolcheck'}/;
	$frsevent		= 1 if $dcdiag_result =~ /$language{'dcdiag_frsevent'}/;
	$kccevent		= 1 if $dcdiag_result =~ /$language{'dcdiag_kccevent'}/;
	$dfsrevent   	= 1 if $dcdiag_result =~ /$language{'dcdiag_dfsrevent'}/;

	my $status_ok = $connectivity && $services && $replications && $advertising && $fsmo && $machine;
	
	$is2003 && ($status_ok &&= $frssysvol);
	($is2008 || $is2012) && ($status_ok &&= $sysvolcheck);

	$isrodc && ($status_ok &&= $rid);
	
	if ($eventlog)
	{
		$is2000 && ($status_ok &&= $kccevent);
		$is2003 && ($status_ok &&= ($kccevent && $frsevent));
		($is2008 || $is2012) && (not $dfsr) && ($status_ok &&= ($kccevent && $frsevent));
		($is2008 || $is2012) && $dfsr && ($status_ok &&= ($kccevent && $dfsrevent));
	}
	
	my $status_text = "Connectivity OK, Services OK, Replications OK, Advertising OK, Fsmo OK, Machine account OK";
	
	$is2003 && ($status_text .= ", FRS Sysvol OK");
	($is2008 || $is2012) && ($status_text .= ", SysVol OK");
	
	$isrodc && ($status_text .= ", Rid Manager OK");  

	if ($eventlog)
	{
		$is2000 && ($status_text .= ", KCC Event OK");
		$is2003 && ($status_text .= ", KCC Event OK, FRS EVent OK");
		$is2008 && (not $dfsr) && ($status_text .= ", KCC Event OK, FRS EVent OK");		
		($is2008 || $is2012) && $dfsr && ($status_text .= ", KCC Event OK, DFSR EVent OK");
	}

	$status_ok && ExitProgram ($OK, $status_text);
	
	defined $failed && ExitProgram ($CRITICAL, $failed);
	defined $warning && ExitProgram ($WARNING, $warning);	

	ExitProgram ($UNKNOWN, "No information is available.");
}

##### PrintUsage #####
sub PrintUsage
{
	print "
Usage:
    check-winad [--dc] [--dfsr] [--noeventlog] [--verbose] [--config *config file*] [--help]

Options:
    --dc
        Checks domain controller functionality by using *dcdiag* tool from
        Windows Support Tools. Following dcdiag tests are performed :

        services, replications, advertising, fsmocheck, ridmanager (not for RODCs),
        machineaccount, kccevent, frssysvol (2003 or later), frsevent (2003 or later),
        sysvolcheck(2008 or later), dfsrevent (2008 or later)

    --dfsr
        Specifies that SysVol replication uses DFS instead of FRS (Windows
        2008 or later)

    --noeventlog
        Don't run the dc tests kccevent and frsevent, since their 24-hour
        scope may not be too relevant for Nagios.

    --verbose
        Prints dcdiag command to run.

    --config *config file*
        check-winad can be localized by using a configuration file
        (*check-winad.config* in the same directory as the plugin itself by
        default). This parameter can be used to specify an alternative
        location for the configuration file.

    --help
        Produces help message

";
	
}

##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;
	
	my $lcomp = "AD";
	print "$lcomp $status_text{$exitcode} - $message";
	exit ($exitcode);
}


__END__

=head1 NAME

check-winad - Nagios compatible check plugin for basic Active Directory health checks 

=head1 SYNOPSIS

B<check-winad> [B<--dc>] [B<--dfsr>] [B<--noeventlog>] [B<--verbose>] [B<--config> I<config file>] [B<--help>]

=head1 DESCRIPTION

B<check-winad> is a Nagios compatible check plugin for basic Active Directory health checks

=head1 OPTIONS

=over 4 

=item B<--dc>

Checks domain controller functionality by using I<dcdiag> tool from Windows Support Tools. Following dcdiag tests are performed :

 services, replications, advertising, fsmocheck, ridmanager (not for RODCs), machineaccount, kccevent, frssysvol (2003 or later), frsevent (2003 or later), sysvolcheck(2008 or later), dfsrevent (2008 or later) 

=item B<--dfsr>

Specifies that SysVol replication uses DFS instead of FRS (Windows 2008 or later)

=item B<--noeventlog>

Don't run the dc tests kccevent and frsevent, since their 24-hour scope may not be too relevant for Nagios.

=item B<--verbose>

Prints dcdiag command to run.

=item B<--config> I<config file>

check-winad can be localized by using a configuration file (I<check-winad.config> in the same directory as the plugin itself by default). This parameter can be used to specify an alternative location for the configuration file.

=item B<--help>

Produces help message.

=back

=head1 CONFIGURATION FILE

dcdiag tool used by B<check-winad> can produce localized output. B<check-winad> can use a configuration file to map localized dcdiag output to pre-defined scanning patterns. The default location is I<check-winad.config> in the same directory as the plugin itself. You can use I<--config> option to specify an alternative location. B<check-winad> will use English language by default if there is no configuration file. Configuration file example:

 # check-winad configuration for language mappings
 # replace strings right to equal signs with your localized dcdiag/netdiag output
 [Language]
 dcdiag_connectivity		= passed test connectivity
 dcdiag_services			= passed test services
 dcdiag_replications		= passed test replications
 dcdiag_advertising			= passed test advertising
 dcdiag_fsmo				= passed test fsmocheck
 dcdiag_rid					= passed test ridmanager
 dcdiag_machine				= passed test machineaccount
 dcdiag_frssysvol			= passed test frssysvol
 dcdiag_sysvolcheck			= passed test sysvolcheck
 dcdiag_frsevent			= passed test frsevent
 dcdiag_kccevent			= passed test kccevent
 dcdiag_dfrsevent			= passed test dfsrevent
 dcdiag_warning				= warning
 dcdiag_failed				= failed

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

=item DCDIAG documentation L<http://technet2.microsoft.com/windowsserver/en/library/f7396ad6-0baa-4e66-8d18-17f83c5e4e6c1033.mspx>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License. L<http://www.opensource.org/licenses/artistic-license.php>

=head1 VERSION

Version 1.8, October 2015

=head1 CHANGELOG

=over 4

=item changes from 1.7

 - Better handling of multi line output (due to longer domain names for example)
 - Remove --member check as the netdiag tool is not available as of Windows 2008

=item changes from 1.6

 - Do not perform RID Manager checks for RODCs (Read-Only Domain Controllers)

=item changes from 1.5

 - Windows 2012 server support
 - Use Windows version information directly
 - make localized string checks in lowercase

=item changes from 1.4

 - Add command line option 'dfsr'
 - --verbose option to print dcdiag/netdiag commands generated
 - introducing configuration file for handling localized output
 - --config option to specify an alternative location for the configuration file
 - member checks on W2008 systems are not performed due to non-availability of netdiag

=item changes from 1.3

 - Windows 2008 support (checks are done in lowercase only)
 - Dropped member test 'trust' as it requires domain admin privileges thus introducing a security weakness.
 - Introducing option 'nokerberos' due to netdiag bug (see Microsoft KB870692)

=item changes from 1.2

 - Add command line option 'noeventlog'.

=item changes from 1.1

 - Support for Windows 2000 domains
 - Use CRITICAL instead of ERROR

=item changes from 1.0

 - remove sysevent test as it can be many other event producers than active directory.

=back

=cut
