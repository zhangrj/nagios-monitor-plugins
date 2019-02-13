#!/usr/bin/perl -wT
#
# Copyright (C) 2010  Andrey Mitroshin <mit@akamit.com>
#
# $Id: check_hds_ams.pl 46 2010-06-16 13:14:40Z mit $
#
# check_hds_ams - Check status of HDS AMS series storage using SNMP v1 SNMP GET query
# requires 
# 1. Net::SNMP module installed 
# 2. SNMP agent configured on the storage system.
# 
# tested with ams500, ams2500
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Nagios);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330, 
# Boston, MA 02111-1307, USA


use strict;

#use lib "/usr/local/nagios/libexec";
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision);
use vars qw($opt_V $opt_h $verbose $o_timeout $opt_C $opt_H);
use Getopt::Long;
use Net::SNMP;

Getopt::Long::Configure('bundling');
GetOptions("V"   => \$opt_V, "version"    => \$opt_V,
         "h"   => \$opt_h, "help"       => \$opt_h,
	 "t=i" => \$o_timeout, "timeout=i"  => \$o_timeout,
         "v" => \$verbose, "verbose"  => \$verbose,
         "C=s" => \$opt_C, "community=s" => \$opt_C,
         "H=s" => \$opt_H, "hostname=s" => \$opt_H);

if (defined $opt_V) { print_revision($0,'1.0'); exit $ERRORS{'OK'}; }
if (defined $opt_h) { print_help(); exit $ERRORS{'OK'}; }
if (defined($o_timeout) && (($o_timeout < 2) || ($o_timeout > 60))) {
           print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}
}

if (not defined($o_timeout)) { $o_timeout = $TIMEOUT; }

if (not defined $opt_H) { print_usage(); exit $ERRORS{'UNKNOWN'}; }
if (not defined $opt_C) { print_usage(); exit $ERRORS{'UNKNOWN'}; }

if (not is_hostname($opt_H) ){
        print "CRITICAL: $opt_H is not a valid host name", "\n";
        exit $ERRORS{"CRITICAL"};
}

# do not check community, just pass is it to Net::SNMP->session as it is
(my $status, my $error) = get_regression_status($opt_H, $opt_C, $o_timeout);
if (not defined $status) {
	print "CRITICAL: ", $error, "\n";
	exit $ERRORS{'CRITICAL'};
}
if ( $status == 0 ) {
	print "OK ($status)\n";
        exit $ERRORS{'OK'};
}
my $info_string = get_regression_info($status);
print "CRITICAL ($status): Check $info_string", "\n";
exit $ERRORS{'CRITICAL'};

sub print_usage {
        print "Usage: $0 -H <host> -C <community> [-t <timeout>]\n";
}

sub print_help  {
        print "\n";
        print_usage();
	print <<EOT;
-v, --verbose
   print extra debugging information 
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: $TIMEOUT)
EOT
}

# sinse is_hostname is not exported from utils.pm, just copy-past in here

sub is_hostname {
        my $host1 = shift;
        return 0 unless defined $host1;
        if ($host1 =~ m/^[\d\.]+$/ && $host1 !~ /\.$/) {
                if ($host1 =~ m/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                        return 1;
                } else {
                        return 0;
                }
        } elsif ($host1 =~ m/^[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)*\.?$/) {
                return 1;
        } else {
                return 0;
        }
}

#
# get regression status. return ($status, "ok") or (undef, "error reason")
# 
sub get_regression_status {
	my $host = shift;
	my $community = shift;
	my $timeout = shift;
	my $oid = "1.3.6.1.4.1.116.5.11.1.2.2.1.0";

	my ($session, $error) = Net::SNMP->session(
      		-hostname  => $host,
      		-community => $community,
		-timeout => $timeout,
	);
	return (undef, $error) if not defined $session;

	my $result = $session->get_request(-varbindlist => [ $oid ],);
	return (undef, $session->error()) if not defined $result;

	$session->close();
	return ($result->{$oid}, "ok");
}

# 
# decypher status integer. return human readable string.
# %regression_status hash constructed out of the dfraid.mib, available from HDS cd that
# comes with ams storage
#
sub get_regression_info {
	my @errs = ();
	my $result = "";
	my $status = shift;

	my %regression_status = (
		0 => 'drive',
		1 => 'spare drive',
		2 => 'data drive',
		3 => 'ENC',
		5 => '', 		# not used
		6 => 'warning',
		7 => 'Other controller',
		8 => 'UPS',
		9 => 'loop',
		10 => 'path',
		11 => 'NAS Server',
		12 => 'NAS Path',
		13 => 'NAS UPS',
		14 => '', 		# not used
		15 => '', 		# not used
		16 => 'battery',
		17 => 'power supply',
		18 => 'AC',
		19 => 'BK',
		20 => 'fan',
		21 => '', 		# not used
		22 => '', 		# not used
		23 => '', 		# not used
		24 => 'cache memory',
		25 => 'SATA spare drive',
		26 => 'SATA data drive',
		27 => 'SENC status',
		28 => 'HostConnector',
		29 => '', 		# not used
		30 => '', 		# not used
		31 => '', 		# not used
	);
	# $status is a bitmask. check if the bit is raised and tell the corresponding message.
	for my $i (0..31) {
		my $mask = 1 << $i;
		if ( $status & $mask  ) {
			push @errs, $regression_status{ $i };
		}
	}
	# separate messages by commas to be human friendly
	for my $err (@errs) {
		$result .= $err;
		$result .= ", " unless $errs[-1] eq $_;
	}
	return $result;
}
