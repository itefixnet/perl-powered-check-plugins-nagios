#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-oracle.pl - Nagios compatible check plugin for basic Oracle health checks
#

use strict;
use warnings;
use Getopt::Long;

our $iswin = $^O eq "MSWin32";

if ($iswin)
{
	use Win32::TieRegistry;
}

use File::Temp qw/ tempfile tempdir /;

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

our $TNS = 'tns';
our $LOGIN = 'login';
our $CACHE = 'cache';
our $TABLESPACE = 'tablespace';

our %command_text = (
	$TNS => "TNS",
	$LOGIN => "LOGIN",
	$CACHE => "CACHE",
	$TABLESPACE => "TABLESPACE"
);

our $command = '';
our $sid = undef;
our $user = undef;
our $password = undef;
our $warning = undef;
our $critical = undef;
our $tablespace = undef;
our $hostname = undef;
our $oraclehome = undef; # try to guess !!
our $verbose = 0;

GetOptions (
	"tns"	=> sub { $command = $TNS },
	"login" => sub { $command = $LOGIN },
	"cache" => sub { $command = $CACHE },
	"tablespace=s" => \$tablespace,
	"sid=s" => \$sid,
	"user=s" => \$user,
	"password=s" => \$password,
	"warning=s" => \$warning,	
	"critical=s" => \$critical,
	"hostname=s" => \$hostname,
	"oraclehome=s" => \$oraclehome,
	"help" => sub { PrintUsage() },
	"verbose" => \$verbose
) || ExitProgram($UNKNOWN, "Usage problem");

$oraclehome = $oraclehome || $ENV{ORACLE_HOME} || ($iswin && $Registry->{"LMachine\\SOFTWARE\\ORACLE\\ORACLE_HOME"});

ExitProgram($UNKNOWN, "No ORACLE_HOME value!") if not $oraclehome;

my (undef, $sqltmp) = tempfile(undef, OPEN => 0);
$sqltmp .= '.sql';
print "ORACLE_HOME is $oraclehome\nTemporary script file is $sqltmp\n" if $verbose;

CTRLSW: {
	($command eq $TNS) && do { CheckTns ($sid || $hostname); last CTRLSW };
	($command eq $LOGIN) && do { CheckLogin ($sid); last CTRLSW };
	($command eq $CACHE) && do { CheckCache ($sid, $user, $password, $warning, $critical); last CTRLSW };
	(defined $tablespace) && do 
	{ 
		$command = $TABLESPACE; 
		CheckTablespace ($sid, $user, $password, $tablespace, $warning, $critical);
		last CTRLSW
	};
}

#### SUBROUTINES ####

##### Check TNS #####
sub CheckTns
{
	my $tnstarget = shift;
	
	$tnstarget || ExitProgram($UNKNOWN, "No SID or hostname specified!");
	print "Check TNS $tnstarget ...\n" if $verbose;
	
	my $result =  lc `\"$oraclehome/bin/tnsping\" $tnstarget` or ExitProgram($UNKNOWN, "Tnsping run problem");
	print "Tnsping output is:\n$result" if $verbose;
	
	($result =~ /ok/) || ExitProgram($CRITICAL, "No TNS Listener on $tnstarget");
	my ($replytime) = ($result =~ /ok \((\S+)/);
	
	my $state = $OK;
	defined $warning && ($replytime >= $warning) && ($state = $WARNING);
	defined $critical && ($replytime >= $critical) && ($state = $CRITICAL);

	my $resultstr = 
		"reply time $replytime msecs from $tnstarget" .
		"|'$tnstarget reply'=$replytime" . "ms;" . 
		(defined $warning ? $warning : "") . ";" . (defined $critical ? $critical : "") . ";";
		
	ExitProgram($state, $resultstr);
}

##### Check login #####
sub CheckLogin
{
	my $tnstarget = shift;
	
	$tnstarget || ExitProgram($UNKNOWN, "No SID specified!");
	print "Check login on $tnstarget ...\n" if $verbose;
	
	my $result = `\"$oraclehome/bin/sqlplus\" -S dummy/user\@$tnstarget < NUL` or ExitProgram($UNKNOWN, "Sqlplus run problem");
	print "Sqlplus output is:\n$result" if $verbose;
	
	# OK result
	($result =~ /ORA-01017/) && ExitProgram($OK, "dummy login connected");

	my ($message) = ($result =~ /ORA-(.*)\n/);
	ExitProgram($CRITICAL, "ORA-$message" );

}

##### Check cache ####
sub CheckCache
{
	my ($tnstarget, $user, $password, $warning, $critical) = @_;
	
	$tnstarget || ExitProgram($UNKNOWN, "No SID specified!");
	($user && $password) || ExitProgram($UNKNOWN, "No username and password specified!");
	print "Check cache on $tnstarget ...\n" if $verbose;	
	$warning && $critical && ($warning < $critical) && ExitProgram($UNKNOWN, "Warning level is less than Critical");
	
	my ($buf_hr) = (RunSqlScript($tnstarget, $user, $password, "
set pagesize 0
set numf '9999999.99'
select (1-(pr.value/(dbg.value+cg.value)))*100 from v\$sysstat pr, v\$sysstat dbg, v\$sysstat cg
where pr.name='physical reads' and dbg.name='db block gets'and cg.name='consistent gets';
quit;
") =~ /\s+(\S+)/);

	my ($lib_hr) = (RunSqlScript($tnstarget, $user, $password, "
set pagesize 0
set numf '9999999.99'
select sum(lc.pins)/(sum(lc.pins)+sum(lc.reloads))*100 from v\$librarycache lc;
quit;
") =~ /\s+(\S+)/);
	
	my $state = $OK;
	$warning && ($buf_hr <= $warning or $lib_hr <= $warning) && ($state = $WARNING);
	$critical && ($buf_hr <= $critical or $lib_hr <= $critical) && ($state = $CRITICAL);	

	$critical ||= ''; $warning ||= ''; # handle undefined values
	ExitProgram($state, sprintf("Cache Hit Rates: %.0f%% Lib -- %.0f%\% Buff|lib=%.0f%%;$critical;$warning;0;100 buffer=%.0f%%;$critical;$warning;0;100", $lib_hr, $buf_hr, $lib_hr, $buf_hr));
}

##### Check Tablespace
sub CheckTablespace
{
	my ($tnstarget, $user, $password, $tablespace, $warning, $critical) = @_;
	
	print "Check cache on $tnstarget ...\n" if $verbose;
	$tnstarget || ExitProgram($UNKNOWN, "No SID specified!");
	($user && $password) || ExitProgram($UNKNOWN, "No username and password specified!");
	$tablespace || ExitProgram($UNKNOWN, "No tablespace specified!");
	$warning && $critical && ($warning > $critical) && ExitProgram($UNKNOWN, "Warning level is greater than Critical");
	
	my $result = RunSqlScript($tnstarget, $user, $password, "
set pagesize 0
set numf '9999999.99'
SELECT
	NVL(b.tablespace_name,nvl(a.tablespace_name,'UNKOWN')) name,
	((kbytes_alloc-nvl(kbytes_free,0))/kbytes_alloc)*100 pct_used,
	NVL(kbytes_alloc/1024,0) alloc,
	NVL(kbytes_free/1024,0) free,
	autoextensible
FROM
	(SELECT
		SUM(bytes)/1024 Kbytes_free,
		max(bytes)/1024 largest,
		tablespace_name
	FROM
		sys.dba_free_space
	GROUP BY
		tablespace_name
	) a,
	(SELECT SUM(bytes)/1024 Kbytes_alloc,
		tablespace_name
	FROM
		sys.dba_data_files
	GROUP BY
		tablespace_name
	) b,
	(SELECT
		tablespace_name,
		autoextensible
	FROM
		sys.dba_data_files
	GROUP BY
		tablespace_name,
		autoextensible
	HAVING
		autoextensible='YES'
	) c
	WHERE
		a.tablespace_name (+) =  b.tablespace_name
	AND
		c.tablespace_name (+) = b.tablespace_name
;
quit;
");

	my $state = $UNKNOWN;
	my ($table, $pctinuse, $allocmb, $freemb, $autoex);
	
	foreach (split /\n/, $result)
	{ 
		($table, $pctinuse, $allocmb, $freemb, $autoex) = split /\s+/;		
		next if $tablespace ne $table;
		
		$state = $OK;
		# Give only warning if the tablespace is autoextensible and critical limit is reached
		$critical && ($pctinuse >= $critical) && ($state = ($autoex) ? $WARNING : $CRITICAL);
		$warning && ($pctinuse >= $warning) && ($state = $WARNING);
		last;		
	}
	
	$critical ||= ''; $warning ||= ''; # handle undefined values
	ExitProgram($state, ($state ne $UNKNOWN) 
	? sprintf ("$tnstarget : $tablespace - %.0f%% used [ %.0f / %.0f MB available ]|$tnstarget=%.0f%%;$warning;$critical;0;100", $pctinuse, $freemb, $allocmb, $pctinuse)
	: "No data returned by Oracle - tablespace $tablespace not found?");
}
	
sub RunSqlScript
{
	my ($tnstarget, $user, $password, $sqlscript) = @_;	
	
	# Create a temporary script file
	open CHECK, ">$sqltmp" or ExitProgram($UNKNOWN, "Create SQL script file");
	print CHECK $sqlscript;
	close CHECK or ExitProgram($UNKNOWN, "Create SQL script file");
	
	my $result =`\"$oraclehome\\bin\\sqlplus\" -S $user/$password\@$tnstarget \@\"$sqltmp\"`;
	print "Sqlplus output is:\n$result" if $verbose;
	my ($message) = ($result =~ /ORA-(.*)\n/);
	$message && ExitProgram($CRITICAL, "ORA-$message" );

	unlink $sqltmp;
	return $result;
}
##### PrintUsage #####
sub PrintUsage
{
	print "
Usage:
    check-oracle [--tns | --login | --cache | --tablespace *tablespace
    name*] [--sid *Oracle SID*] [--user *user*] [--password *password*]
    [--hostname *hostname*] [--warning *threshold*] [--critical *threshold*]
    [--oraclehome *home path*] [--verbose] [--help]

Options:
    --tns [ --sid *SID* | --hostname *hostname* ] [--warning *warning*] [
    --critical *critical* ]
        Performs an Oracle ping on the *SID/hostname* by using *tnsping*
        tool, and returns CRITICAL if not succeeded. Returns respectively
        CRITICAL or WARNING if tns reply time is larger than *critical* or
        *warning*.

    --login --sid *SID*
        Attempts a dummy login on the *SID* and returns CRITICAL if not
        *ORA-01017: invalid username/password* returns.

    --cache --sid *SID* --user *user* --password *password* [--warning
    *warning*] [ --critical *critical* ]
        Checks local database for library and buffer cache hit ratios on the
        *SID*, by using credentials *user/password* to logon. Returns
        respectively CRITICAL or WARNING if at least one cache ratio is
        below *critical* or *warning*.

    --tablespace *tablespace* --sid *SID* --user *user* --password
    *password* [--warning *warning*] [ --critical *critical* ]
        Checks local database for tablespace capacity of the *tablespace* on
        the *SID*, by using credentials *user/password* to logon. Returns
        respectively CRITICAL or WARNING if the usage percent is more than
        *critical* or *warning*.

    --oraclehome *home path*
        check-oracle tries to locate Oracle home directory by using
        ORACLE_HOME env variable or values in the registry. You can use this
        option if you want to override plugin's path location behaviour.

    --verbose
        Produces detailed messages for debugging.

    --help
        Produces a help message.

";
}

##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;
	printf "%s : %s\n", (defined $command_text{$command} ? "$command_text{$command}" : ""), "$status_text{$exitcode} - $message";
	exit ($exitcode);
}


__END__

=head1 NAME

check-oracle -  Nagios compatible check plugin for basic Oracle health checks

=head1 SYNOPSIS

B<check-oracle> [B<--tns> | B<--login> | B<--cache> | B<--tablespace> I<tablespace name>] [B<--sid> I<Oracle SID>] [B<--user> I<user>] [B<--password> I<password>] [B<--hostname> I<hostname>]  [B<--warning> I<threshold>] [B<--critical> I<threshold>] [B<--oraclehome> I<home path>] [B<--verbose>] [B<--help>]

=head1 DESCRIPTION

B<check-oracle> works as a Nagios NRPE plugin for basic Oracle health checks like tns ping, login, cache and tablespaces

=head1 OPTIONS

=over 4 

=item B<--tns> [ --sid I<SID> | --hostname I<hostname> ] [--warning I<warning>] [ --critical I<critical> ]

Performs an Oracle ping on the I<SID/hostname> by using I<tnsping> tool, and returns B<CRITICAL> if not succeeded. Returns respectively B<CRITICAL> or B<WARNING> if tns reply time is larger than I<critical> or I<warning>.


=item B<--login> --sid I<SID>

Attempts a dummy login on the I<SID> and returns B<CRITICAL> if not I<ORA-01017: invalid username/password> returns.

=item B<--cache> --sid I<SID> --user I<user> --password I<password> [--warning I<warning>] [ --critical I<critical> ]

Checks local database for library and buffer cache hit ratios on the I<SID>, by using credentials I<user/password> to logon. Returns respectively B<CRITICAL> or B<WARNING> if at least one cache ratio is below I<critical> or I<warning>.

=item B<--tablespace> I<tablespace> --sid I<SID> --user I<user> --password I<password> [--warning I<warning>] [ --critical I<critical> ]

Checks local database for tablespace capacity of the I<tablespace> on the I<SID>, by using credentials I<user/password> to logon. Returns respectively B<CRITICAL> or B<WARNING> if the usage percent is more than I<critical> or I<warning>.

=item B<--oraclehome> I<home path>

B<check-oracle> tries to locate Oracle home directory by using ORACLE_HOME env variable or values in the registry. You can use this option if you want to override plugin's path location behaviour.

=item B<--verbose>

Produces detailed messages for debugging.

=item B<--help>

Produces a help message.

=back

=head1 EXAMPLES

 check-oracle --tns --sid MYORACLE

Pings the SID I<MYORACLE> and returns CRITICAL if not succeeded or NORMAL otherwise.

 check-oracle --login --sid MYORACLE

Performs a dummy login on the SID I<MYORACLE> and returns CRITICAL if the server answers with a message other than ORA-01017 or NORMAL otherwise.

 check-oracle --cache --sid MYORACLE --user ping --password pong --warning 99 --critical 95

Logs on by using the credentials I<ping/pong> on the SID I<MYORACLE>, queries system tables and calculates library and buffer cache hit ratios. Returns CRITICAL if at least one of the hit ratios is below 95%, WARNING if it is below 99% or NORMAL otherwise.

 check-oracle --tablespace MYTABLE --sid MYORACLE --user ping --password pong --warning 90 --critical 95

Logs on by using the credentials I<ping/pong> on the SID I<MYORACLE>, queries system tables and calculates the usage ratio for the tablespace I<MYTABLE>. Returns CRITICAL if the usage is over 95%, WARNING if it is over 90%, or NORMAL otherwise.

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

=item Nagios NRPE documentation L<http://nagios.sourceforge.net/docs/nrpe/NRPE.pdf>

=item Standard Nagios plugins, B<check-oracle> plugin

=item check-oracle_vbs at Nagios Exchange L<http://www.nagiosexchange.org/Oracle.153.0.html?&tx_netnagext_pi1[p_view]=788>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License. L<http://www.opensource.org/licenses/artistic-license.php>

=head1 VERSION

Version 1.1, May 2011

=head1 CHANGELOG

=over 4

=item changes from 1.0

 - performance data output for tns check
 - ability to specify warning and critical levels for tns checks
 - Windows independency

=item Initial version

=back

=cut
