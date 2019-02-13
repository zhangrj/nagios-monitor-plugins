#!/usr/bin/perl
# Author : jakubowski Benjamin
# Date : 19/12/2005
# check_win_snmp_cpuload.pl IP COMMUNITY PORT warning critical

sub print_usage {
    print "check_win_snmp_cpuload.pl IP COMMUNITY warning critical\n";
}

$PROGNAME = "check_win_snmp_cpuload.pl";

if  ( @ARGV[0] eq "" || @ARGV[1] eq "" || @ARGV[2] eq "" ) {
    print_usage();
    exit 0;
}

$STATE_CRITICAL = 2;
$STATE_WARNING = 1;
$STATE_UNKNONW = 3;

$STATE_OK = 0;

$IP=@ARGV[0];
$COMMUNITY=@ARGV[1];
$warning=@ARGV[2];
$critical=@ARGV[3];
$resultat =`snmpwalk -v 1 -c $COMMUNITY $IP 1.3.6.1.2.1.25.3.3.1.2`;
if ( $resultat ) {
    @pourcentage = split (/\n/,$resultat);
    $i=0;
    foreach ( @pourcentage ) {
	s/HOST-RESOURCES-MIB::hrProcessorLoad.\d+ = INTEGER://g;	
	$use_total+=$_;
	$i++;
    }
    $use = $use_total / $i ;

    if ( $use < $warning ) {
	print "OK : CPU load $use\n";
	exit $STATE_OK;
    } elsif ( $use < critical ) {
	print "WARNING : CPU load $use\n";
	exit $STATE_WARNING;
    } else {
	print "CRITICAL : CPU load :$use\n";
	exit $STATE_CRITICAL;
    }
} else {
    print "Unkonwn  : No response\n";
    exit $STATE_UNKNONW;
}


