#!/usr/local/bin/perl

# $Id: 2.test_retrieving_dummy_account.t,v 1.1.1.1 2004/11/26 14:43:39 erwan Exp $
#
# Test sequence for Finance::PPM
#
# erwan lemonnier - 2004
#

use Test::More tests => 3;

use Data::Dumper;
use lib "../blib/lib/";
use_ok "Finance::SE::PPM";

# test retrieving a wrong account

my $ppm;

eval {
    $ppm = new Finance::SE::PPM(personnummer => '195602020000',
			    pincode => '12345',
			    debug => 5);
};

ok(($@ eq ""), "created PPM object [$@]");

eval {
    $ppm->fetchAccountStatus();
};

ok(($@ =~ /ERROR: /), "loading fake account [$@]");




