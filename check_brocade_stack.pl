#!/usr/bin/perl
# CVS: @(#): $Id: check_brocade_stack ,v 1.0 2017/12/11 @rhassing
#
# AUTHORS:
#	2017-12-11 Rob Hassing

use lib qw ( /usr/lib/nagios/plugins );
use Getopt::Std;
use Net::SNMP;

$script    = "check_brocade_stack";
$script_version = "1.0";

# SNMP options
my $version = "2c";
my $timeout = 2;

$oid_sysdescr 		= ".1.3.6.1.2.1.1.1.0";
$OID_sysUpTime = '1.3.6.1.2.1.1.3.0';

# Brocade Specific
$oid_stacking	= ".1.3.6.1.4.1.1991.1.1.3.31.1.1.0";	# Is stacking enabled?
$oid_status	= ".1.3.6.1.4.1.1991.1.1.3.31.2.2.1.6";	# Status of the members
$oid_neighbor	= ".1.3.6.1.4.1.1991.1.1.3.31.2.6.1.3";	# The IfIndex for the neighbor port of the stack port on this unit. It returns 0 if neighbor port does not exist for this stack port.

$community = "public"; 		# Default community string

$string = " \"Ready\"";
$standalone = " \"None";

# Do we have enough information?
if (@ARGV < 1) {
     print "Too few arguments\n";
     usage();
}

getopts("h:H:C:");
if ($opt_h){
    usage();
    exit(0);
}
if ($opt_H){
    $hostname = $opt_H;
    # print "Hostname $opt_H\n";
}
else {
    print "No hostname specified\n";
    usage();
    exit(0);
}
if ($opt_C){
    $community = $opt_C;
}
else {
     # print "Using community $community\n";
}


my $version = "2c";
  ($s, $e) = Net::SNMP->session(
    -community    =>  $community,
    -hostname     =>  $hostname,
    -version      =>  $version,
    -timeout      =>  $timeout,
  );
  if (!defined($s->get_request($oid_sysdescr))) {
    print "Agent not responding, tried SNMP v2\n";
    exit(1);
  }

	my $stackresult = $s->get_request(-varbindlist => [ $oid_stacking ],);
	if ($stackresult->{$oid_stacking} == 1) {
          print "Stacking is enabled.\n";
          $stack = 1;
          } else {
            if ($stackresult->{$oid_stacking} == 0) {
              $returnstring = "This is not a Stack.";
              $status = 0;
            } else {
              if ($stackresult->{$oid_stacking} == 2) {
                $returnstring = "Stacking is disabled.";
                $status = 1;
            } else {
              print "That didn't work out!";
            }
          }
        }
# Close the session
$s->close();

if ($stack == 1){
if ($status != 2){
find_stackinfo();
}
if ($status != 2){
probe_stack();
}
}

if($status == 0){
    print "Status is OK - $returnstring\n";
    exit $status;
}
elsif($status == 1){
    print "Status is a Warning Level\n";
    exit $status;
}
elsif($status == 2){
    print "Status is CRITICAL - $returnstring\n";
    exit $status;
}
else{
    print "Plugin error! SNMP status unknown\n";
    exit $status;
}

exit 2;


#################################################
# Find Stackinfo 
#################################################

sub find_stackinfo {
@qr_output1 = `snmpwalk -v 2c -c $community $hostname $oid_status`;
foreach(@qr_output1)
{
        chomp($_);
        my @qr_line1 = split(/:/);
        $stack = @qr_line1[3];
       if ($stack eq $string) {
       print "stack: $stack\n";
       } else {
       if ($stack eq $standalone) {
       print "Stack is standalone!\n";
       exit(0);
       } else {
       print "Stack not ok: $stack\n";
       $status = 2;
       $returnstring = "Stackmember is not Ready!";
    }
}
}
}

####################################################################
# Gathers data about stack interface                              #
####################################################################


sub probe_stack {
@qr_output1 = `snmpwalk -v 2c -c $community $hostname $oid_neighbor`;
foreach(@qr_output1)
  {
        chomp($_);
        my @qr_line1 = split(/:/);
        $stack = @qr_line1[3];
      if ($stack==0) {
        print "CRITICAL - port down $stack\n";
        $status = 2; 
      } elsif ($stack!=0) {
#        print "neighbor $stack\n";
#	 $returnstring = "Stack is OK!";
    }
  }
}


####################################################################
# help and usage information                                       #
####################################################################

sub usage {
    print << "USAGE";
--------------------------------------------------------------------
$script v$script_version

Monitors status of a Brocade Stack

Usage: $script -H <hostname> -c <community> [...]

Options: -H 	Hostname or IP address
         -C 	Community (default is public)

--------------------------------------------------------------------	 
Copyright 2017 Rob Hassing
	 
This program is free software; you can redistribute it or modify
it under the terms of the GNU General Public License
--------------------------------------------------------------------		
		
USAGE
     exit 1;
}


