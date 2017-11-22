#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;

# PROTOTYPES
sub dieWithUsage(;$);

# GLOBALS
my $SCRIPT_NAME = basename( __FILE__ );
my $SCRIPT_PATH = dirname( __FILE__ );

# MAIN
dieWithUsage("one or more parameters not defined") unless @ARGV >= 1;
my $suite = shift;
my $scale = shift || 2;
dieWithUsage("suite name required") unless $suite eq "tpcds" or $suite eq "tpch";

chdir $SCRIPT_PATH;
if( $suite eq 'tpcds' ) {
	chdir "sample-queries-tpcds";
} else {
	chdir 'sample-queries-tpch';
} # end if
my @queries = glob '*.sql';

my $db = { 
	'tpcds' => "tpcds_bin_partitioned_orc_$scale",
	'tpch' => "tpch_flat_orc_$scale"
};

my $iterations = 3;
my @output = [];

#print "filename,status,raw time,time,rows\n";
for my $query ( @queries ) {
        my $counter = 1;
        my @runs = [];

        print "Running " . $query . " ...\n";
 
        while ($counter <= $iterations) {
            print "  iteration " . $counter . "\t";

	    my $logname = "$query.log";
	    my $cmd="echo 'use $db->{${suite}}; source $query;' | hive 2>&1  | tee $query.log";
	    
	    my @hiveoutput=`$cmd`;
	    die "${SCRIPT_NAME}:: ERROR:  hive command unexpectedly exited \$? = '$?', \$! = '$!'" if $?;

	    foreach my $line ( @hiveoutput ) {
		    if ( $line =~ /Time taken:\s+([\d\.]+)\s+seconds,\s+Fetched:\s+(\d+)\s+row/ ) {
                            push @runs, $1;
			    print "$query,success,$1,$2\n"; 
		    } elsif ( $line =~ /^FAILED: / ) {
			    print "$query,failed\n"; 
			    push @output, "$query,failed\n"; 
                            $counter = 3;
                    } # end if
	    } # end foreach
        $counter += 1;
    } # end of while

#    my $totalRun = 0;
#    $totalRun = $totalRun += 1 for @runs;
#   
#    print  "Total Runs: " . $totalRun;
#
#    my $sumRun = 0; 
#    if ( $totalRun >= 3 ) {
#
#      for my $run (@runs) {
#        $sumRun += $run;
#        print $sumRun;
#      }
#
#      print "Sum of Runs: " . $sumRun;
#      my $averageRun = $sumRun/$totalRun;
#
#      print "$query,success,$averageRun\n"; 
#      push @output, "$query,success,$averageRun\n"; 
#    } # end if
} # end for

#foreach my $item (@output) {
#    print $item . "\n";
#}
    

sub dieWithUsage(;$) {
	my $err = shift || '';
	if( $err ne '' ) {
		chomp $err;
		$err = "ERROR: $err\n\n";
	} # end if

	print STDERR <<USAGE;
${err}Usage:
	perl ${SCRIPT_NAME} [tpcds|tpch] [scale]

Description:
	This script runs the sample queries and outputs a CSV file of the time it took each query to run.  Also, all hive output is kept as a log file named 'queryXX.sql.log' for each query file of the form 'queryXX.sql'. Defaults to scale of 2.
USAGE
	exit 1;
}

