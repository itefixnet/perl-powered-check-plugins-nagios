#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-rsync.pl - Nagios compatible check plugin for rsync checks
#

use strict;
use warnings;
use Getopt::Long;
use File::Which;

our $VERSION = "1.0";

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

our $rsync_command = undef;
our @capability_required = ();
our @module_required = ();
our $version_required = undef;
our $protocol_required = undef;
our $print_capability = 0;
our $print_module = 0;
our $verbose = 0;
our $help = 0;

GetOptions (
	"rsync=s" => \$rsync_command,
	"capability=s" => \@capability_required,
	"module=s" => \@module_required,
	"version=s" => \$version_required,
	"protocol=s" => \$protocol_required,
	"print_capability" => \$print_capability,
	"print_module" => \$print_module,
	"verbose" => \$verbose,
	"help" => sub { PrintUsage() }
) || PrintUsage();

# Check if rsync command is available
(defined $rsync_command && -e $rsync_command) || which('rsync') || ExitProgram ($UNKNOWN, "Could not locate rsync program.");

# Treat comma spearated values as well
@capability_required = split(/,/, join(',', @capability_required));
@module_required = split(/,/, join(',', @module_required));

# Run rsync to collect version information
my $rsync_output = `\"$rsync_command\" --version`;
$rsync_output =~ s/\n/ /g; 

my ($rsync_version, $protocol_version, $caps) = ($rsync_output =~ /^rsync\s+version\s+(\S+)\s+protocol\s+version\s+(\d+).*Capabilities:\s+(.*)rsync comes with/);

# Generate capability list if required
my @capability_available = ();
if ($print_capability or @capability_required)
{
	@capability_available =  split /,\s+/, $caps;
}

# Generate module list if required
my @module_available = ();
if ($print_module or @module_required)
{
	my $module_output = `\"$rsync_command\" localhost::`;
	foreach my $lmod (split (/\n/, $module_output))
	{
		push @module_available, ($lmod =~ /(\S+)/);
	}
}	

# Create message string
my $str_version_proto = "Version $rsync_version, protocol $protocol_version";
my $str_capability = $print_capability ? (", Capabilities: " . ((@capability_available) ? join(', ', @capability_available) : "no capabilities")) : "";
my $str_module = $print_module ? ( ", Modules: " . ((@module_available) ? join(', ', @module_available) : "no modules")): "";
my $info_message = $str_version_proto . $str_capability . $str_module;

# Version check
if (defined $version_required)
{
	($rsync_version ge $version_required) || ExitProgram ($CRITICAL, "Version $version_required is required ($info_message)");
}

# Protocl check
if (defined $protocol_required)
{
	($protocol_version ge $protocol_required) || ExitProgram ($CRITICAL, "Protocol $protocol_required is required ($info_message)");
}

# Capability check
foreach my $lcap (@capability_required)
{
	grep ("\L$lcap" eq lc, @capability_available) || ExitProgram ($CRITICAL, "Missing capability $lcap ($info_message)");
}

# Module check
foreach my $lmod (@module_required)
{
	grep( "\L$lmod" eq lc, @module_available) || ExitProgram ($CRITICAL, "Missing module $lmod ($info_message)");
}

ExitProgram ($OK, $info_message);

##### PrintUsage #####
sub PrintUsage
{
	print "
Usage:
    check-rsync [ --capability rsync capability[,...] ... ] [ --module rsync
    module[,...] ... ] [ --version rsync version ] [ --protocol rsync
    protocol ] [ --print_capability ] [ --print_module ] [ --rsync rsync
    path] [ --verbose ] [ --help ]

Options:
    --capability rsync capability[,...] ...
        This option specifies the required set of rsync capabilities to
        check for. You can specify several comma separated capabilities for
        one --capability option, as well as several --capability options.
        Optional. Default is no capability check.

    --module rsync module[,...] ...
        This option specifies the required set of rsync modules served by
        the local rsync daemon. You can specify several comma separated
        modules for one --module option, as well as several --module
        options. Optional. Default is no module check.

    --version rsync version
        This option specifies the minimum required version of the rsync
        program. Optional. Default is no version check.

    --protocol rsync protocol
        This option specifies the minimum required version of the rsync
        protocol. Optional. Default is no protocol check.

    --print_capability
        This option instructs check-rsync to print the list of available
        capabilities at the local rsync. Optional. Default output is the
        version and protocol number.

    --print_module
        This option instructs check-rsync to print the list of modules
        served by the local rsync daemon. Optional. Default output is the
        version and protocol number.

    --rsync rsync path
        You can use this option to specify the exact location of the rsync
        program. Optional. Default is rsync via search path.

    --verbose
        Increases output verbosity for debugging.

    --help
        Produces a help message.

";
	
}

##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;
	
	my $lcomp = "RSYNC";
	print "$lcomp $status_text{$exitcode} - $message";
	exit ($exitcode);
}

__END__

=head1 NAME

B<check-rsync> - Nagios compatible check plugin for rsync checks

=head1 SYNOPSIS

B<check-rsync>
	[ B<--capability> I<rsync capability>[,...] ... ]
	[ B<--module> I<rsync module>[,...] ... ]
	[ B<--version> I<rsync version> ]
	[ B<--protocol> I<rsync protocol> ]
	[ B<--print_capability> ]
	[ B<--print_module> ]
	[ B<--rsync> I<rsync path>]
	[ B<--verbose> ]
	[ B<--help> ]

=head1 DESCRIPTION

B<check-rsync> is a Nagios NRPE plugin for checking various aspects of rsync like version, protocol, capabilities and modules

=head1 OPTIONS

=over 4 

=item B<--capability> I<rsync capability>[,...] ... 

This option specifies the required set of rsync capabilities to check for. You can specify several comma separated capabilities for one --capability option, as well as several --capability options. Optional. Default is no capability check.

=item B<--module> I<rsync module>[,...] ...

This option specifies the required set of rsync modules served by the local rsync daemon. You can specify several comma separated modules for one --module option, as well as several --module options. Optional. Default is no module check.

=item B<--version> I<rsync version>

This option specifies the minimum required version of the rsync program. Optional. Default is no version check.

=item B<--protocol> I<rsync protocol>

This option specifies the minimum required version of the rsync protocol. Optional. Default is no protocol check.

=item B<--print_capability>

This option instructs B<check-rsync> to print the list of available capabilities at the local rsync. Optional. Default output is the version and protocol number.

=item B<--print_module>

This option instructs B<check-rsync> to print the list of modules served by the local rsync daemon. Optional. Default output is the version and protocol number.

=item B<--rsync> I<rsync path>

You can use this option to specify the exact location of the rsync program. Optional. Default is I<rsync> via search path.

=item B<--verbose>

Increases output verbosity for debugging.

=item B<--help>

Produces a help message.

=back

=head1 EXAMPLES

 check-rsync

Prints version and protocol number

 check-rsync --version 3.0.2 --protocol 30

Prints the rsync version and protocol. Returns CRITICAL if the version is lower than I<3.0.2> or the protocol is lower than I<30>.

 check-rsync --rsync "C:\program files\icw\bin\rsync.exe" --capability "64-bit files,iconv" --print_cap

Uses I<C:\program files\icw\bin\rsync.exe> as the rsync program and prints the rsync version, protocol and capabilities available. Returns CRITICAL if the capabilities I<64-bit files> and I<iconv> are not among the supported ones.

 check-rsync --module "mirror_a,backup_b" --print_module

Prints the rsync version, protocol and visible modules served by the local daemon. Returns CRITICAL if the modules I<mirror_a> and I<backup_b> are not among the available ones.


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

=item Rsync L<http://rsync.samba.org>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License. L<http://www.opensource.org/licenses/artistic-license.php>

=head1 VERSION

Version 1.0, February 2009

=head1 CHANGELOG

=over 4

=item Initial version

=back

=cut
