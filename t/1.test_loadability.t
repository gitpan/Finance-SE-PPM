# $Id: 1.test_loadability.t,v 1.1.1.1 2004/11/26 14:43:39 erwan Exp $
#
# Test sequence for Finance::PPM
#
# erwan lemonnier - 2004
#

# test loading
use lib "../blib/lib/";
use Test::More tests => 1;
BEGIN { use_ok('Finance::SE::PPM') };




