#!/usr/bin/perl

#---------------------------------------------------------------------
#
# retrieve today's fund status on person's ppm account
#
# erwan - 200407
#
#---------------------------------------------------------------------

# Note: Crypt::SSLeay requires:
#
# MIME-Base64-3.00.tar.gz 
# URI-1.30.tar.gz 
# HTML-Tagset-3.03.tar.gz
# HTML-Parser-3.35.tar.gz
# Crypt-SSLeay-0.51.tar.gz 
# libwww-perl-5.76.tar.gz

# installed crypt::ssleay with:
#   perl5 Makefile.PL PREFIX=/usr/home/USERNAME/usr/local
#   make
#   make test
#   make install
#   make clean


use lib 'blib/lib/';

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Finance::SE::PPM;
use Crypt::SSLeay;

my $PRG_REV = '$Revision: 1.1.1.1 $';
$PRG_REV =~ s/(\d+\.\d+)/$1/;
my $PRG_ID  = 'myppmtoday.pl';


#---------------------------------------------------------------------
#
# syntax()
#
# show argument syntax
#

sub syntax {
    print "  myppmtoday - erwan\@cpan.org - 2004 - $PRG_REV\n";
    print "\n";
    print "syntax: ./".$PRG_ID." [-v] [-u personnummer] [-p pin]\n";
    print "\n";
    print "  -v:               verbose (-v -v: more verbose, etc...)\n";
    print "  -u personnummer:  provide username (default: value in source file)\n";
    print "  -p password:      provide password (default: value in source file)\n";
    print "  -h:               help. this message.\n";
    print "\n";
    exit;
}

#---------------------------------------------------------------------
#
# getAccountReport - returns a string reporting the account status
#                    as retrieved by getAccountFundObjects
#

sub getAccountReport {
    my $PPM    = shift;

    my @funds = $PPM->getAccountFunds();
    
    my $sum = 0;
    my $report = "";

    $report.="PERSON   ".$PPM->{pnr}."\n";
    $report.="DATE     ".$PPM->{date}."\n";
    $report.="\n";
    
    foreach my $fund (@funds) {
	$report.="[".$fund->{ID}."]\n";
	$report.="    NAME        = ".$fund->{NAME}."\n";
	$report.="    TOTAL VALUE = ".$fund->{SHARE_VALUE}."\n";
	$report.="    SHARE PRICE = ".$fund->{SHARE_PRICE}."\n";
	$report.="    ACTUAL %    = ".$fund->{ACTUAL_PCT}."\n";
	$report.="    CHOSEN %    = ".$fund->{CHOSEN_PCT}."\n";

	$sum += $fund->{SHARE_VALUE};
    }
    
    $report.="\n";
    $report.="TOTAL    = $sum\n";
    $report.="STATUS   = ".($PPM->isChangingFunds() ? "fund change in progress" : "normal")."\n";
    $report.="\n";

    return $report;
}

#---------------------------------------------------------------------
#
# getAccountShortReport
#

sub getAccountShortReport {
    my $PPM    = shift;

    my @funds = $PPM->getAccountFunds();
    
    my $sum = 0;
    my $report = "";
    my $dte = $PPM->{date};
    
    foreach my $fund (@funds) {
	$report.=join(":", 
		      "DTE=".$fund->{DATE}, 
		      "FID=".$fund->{ID}, 
		      "PRC=".$fund->{SHARE_PRICE}, 
		      "CNT=".$fund->{SHARE_CNT}, 
		      "VAL=".$fund->{SHARE_VALUE}, 
		      "NO%=".$fund->{ACTUAL_PCT}, 
		      "WA%=".$fund->{CHOSEN_PCT},
		      "\n",
		      );
	$sum += $fund->{SHARE_VALUE};
    }
    
    $report.="DTE=$dte:SUM=$sum\n";;

    return $report;
}

#---------------------------------------------------------------------
#
# parse arguments
#

my $OptPnr;
my $OptPin;
my $OptVbs = 0;
my $OptHlp;
my $OptSht;

GetOptions("pnr|u=s",    \$OptPnr,
	   "pin|p=s",    \$OptPin,
	   "short|s",    \$OptSht,
           "verbose|v+", \$OptVbs,
           "help|h",     \$OptHlp);

syntax() 
    if ($OptHlp);

if (!defined $OptPnr || !defined $OptPin) {
    die "ERROR: you must provide personnummer and pin code (-h for help)";
}

#---------------------------------------------------------------------
#
# retrieve html page describing account status
#

my $ppm = new Finance::SE::PPM(personnummer => $OptPnr, 
			   pincode => $OptPin,
			   debug => $OptVbs);

#---------------------------------------------------------------------
#
# extract account info
#

$ppm->fetchAccountStatus(); 

#---------------------------------------------------------------------
#
# print summary
#

if ($OptSht) {
    print &getAccountShortReport($ppm);
} else {
    print &getAccountReport($ppm);
}

