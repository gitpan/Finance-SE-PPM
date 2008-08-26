# -------------------------------------------------------------------------
#
#   Finance::SE::PPM.pm - A module for fetching account information from the swedish PPM
#
#   $Id: PPM.pm,v 1.3 2008-08-26 10:30:35 erwan Exp $
#  
#   Erwan Lemonnier - 2004
#
# -------------------------------------------------------------------------

# TODO: parse amount not yet invested while changing fund profile

package Finance::SE::PPM;

die "Do NOT use this module";

# Note: Crypt::SSLeay requires:
#
# MIME-Base64-3.00.tar.gz 
# URI-1.30.tar.gz 
# HTML-Tagset-3.03.tar.gz
# HTML-Parser-3.35.tar.gz
# Crypt-SSLeay-0.51.tar.gz 
# libwww-perl-5.76.tar.gz
#
# installed crypt::ssleay with:
#   perl5 Makefile.PL PREFIX=/usr/home/USERNAME/usr/local
#   make
#   make test
#   make install
#   make clean

use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak confess);

use HTTP::Request::Common qw(POST GET);
use HTTP::Headers;
use HTTP::Cookies;
use LWP::UserAgent;
use Crypt::SSLeay;
use HTML::TreeBuilder;
use Class::XPath;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();

our $VERSION = '0.04';

#---------------------------------------------------------------------
#
# Parameters
#

# correspondance html form's inputs / PPM object fields
my $HTML_INPUT_PPM = {
    "personnummer" => "pnr",
    "pin" => "pin",
};

my $URL_LOGIN  = "https://secure.ppm.nu/tpp/securelogin/3:11;x;:1:1;1101;:";
my $URL_LOGOUT = "https://secure.ppm.nu/tpp/securelogin/3:20;:1:1;1102;:";

my $SERVER = "secure.ppm.nu";
my $PROTO  = "https://";

# default debug/verbose level
my $DEBUG = 0;

#---------------------------------------------------------------------
#
# _init_xpath - add Class::XPath routines to HTML::Element
#

sub _init_xpath {
    Class::XPath->add_methods(target         => 'HTML::Element',
			      get_parent     => 'parent',
			      get_name       => 'tag',
			      get_attr_names => sub { my %attr = shift->all_external_attr;
						      return keys %attr; 
						  },
			      get_attr_value => sub { my %attr = shift->all_external_attr;
						      return $attr{$_[0]}; 
						  },
			      get_children   => sub { grep { ref $_ } shift->content_list },
			      get_content    => sub { grep { not ref $_ } shift->content_list },
			      get_root       => sub { local $_=shift; 
						      while($_->parent) 
						      { $_ = $_->parent }
						      return $_; 
						  },
			      );
  }

&_init_xpath();

######################################################################
#
#
#   Public methods
#
#
######################################################################

#---------------------------------------------------------------------
#
# new Finance::PPM - create PPM object to handle 1 account
#
# parameters: personnummer -> pnr
#             pincode -> pin
#             debug -> int

sub new {
    my($class,%args) = @_;

    my $PPM = {};
    bless($PPM,$class);
    
    $PPM->{pnr} = $args{personnummer} if (exists $args{personnummer});
    $PPM->{pin} = $args{pincode}      if (exists $args{pincode});

    if (exists $args{debug}) {
	croak "ERROR: debug must be a number [".$args{debug}."]" 
	    if ($args{debug} !~ /^\d+$/);	
	$DEBUG = $args{debug};
    }

    $PPM->{referer} = "";

    # initialise PPM user agent
    my $ua = new LWP::UserAgent;
    $ua->timeout(10);
    $ua->agent("Mozilla/5.0");
    $ua->cookie_jar(HTTP::Cookies->new(file => ".cookies.txt"));
    $ua->requests_redirectable(['GET','POST','HEAD']);
    $PPM->{useragent} = $ua;

    return $PPM; 
}

#---------------------------------------------------------------------
#
# getFundInfo - get info about one fund
#
# parameters: fundid -> PPM fund id
# returns: a hash describing this fund (name, value, etc)
#

sub getFundInfo {
    croak "Not implemented yet.";
}

#---------------------------------------------------------------------
#
# fetchAccountStatus - retrieve this person's account
#

sub fetchAccountStatus {
    my($PPM,$pnr,$pin) = @_;

    $PPM->_chk_pnr_pin();
    $PPM->_set_current_date();
    _debug(5,"content of PPM object before loading account:\n".Dumper($PPM));

    $PPM->_account_login();
    $PPM->_account_logout();
    $PPM->_extract_fund_info();    
}

#---------------------------------------------------------------------
#
# getAccountFunds - returns an array of hashes describing 
#                   each fund's status
#

sub getAccountFunds {
    my $PPM    = shift;

    croak "ERROR: getAccountFundObjects without calling loadAccountStatus first"
	if (!exists $PPM->{account});

    return @{$PPM->{account}};
}

#---------------------------------------------------------------------
#
# isChangingFunds() - check if funds are being changed on account
#

sub isChangingFunds {
    my $PPM = shift;   

    croak "ERROR: getAccountFundObjects without calling loadAccountStatus first"
	if (!exists $PPM->{html});

    return $PPM->{html}->as_string() =~ /fondhandelpagar.gif/g;
}

#---------------------------------------------------------------------
#
# setProxy
#

sub setProxy {
    my($PPM,$proxy) = @_;
    $ENV{HTTPS_PROXY} = $proxy;
}

######################################################################
#
#
#   Private methods
#
#
######################################################################

#---------------------------------------------------------------------
#
# debug - intern log function
#

sub _debug {
    my($lvl,$msg) = @_;
    if ($DEBUG >= $lvl) {
	print "PPM.PM DEBUG[$lvl]: $msg\n";
    }
}

#---------------------------------------------------------------------
#
# _chk_pnr_pin
#
# verify that this PPM object has received a valid pincode & personnummer
#

sub _chk_pnr_pin {
    my $PPM = shift;

    croak "ERROR: no personnummer specified"              if (!defined $PPM->{pnr});
    croak "ERROR: no pin code specified"                  if (!defined $PPM->{pin});
    croak "ERROR: invalid personnummer [".$PPM->{pnr}."]" if ($PPM->{pnr} !~ /^\d{12}$/);
    croak "ERROR: invalid pin [".$PPM->{pin}."]"          if ($PPM->{pin} !~ /^\d{5}$/);
}

#---------------------------------------------------------------------
#
# _set_current_date() - set PPM object to today's date
#

sub _set_current_date {
    my $PPM = shift;
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $PPM->{date} = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
}

#---------------------------------------------------------------------
#
# _account_logout()
#
# retrieve PPM login page, login and return identification headers
#

sub _account_logout {
    my $PPM = shift;
    return $PPM->_http_fetch($URL_LOGOUT,'GET');
}

#---------------------------------------------------------------------
#
# _account_login()
#
# retrieve PPM login page, login and return identification headers
#

sub _account_login {
    my $PPM = shift;

    my $pg_login = $PPM->_http_fetch($URL_LOGIN,'GET')->as_string;

    _debug(5,"HTML login page:\n[$pg_login]\n");

    if ($pg_login =~ /^\s*$/) {	
	croak "ERROR: got an empty page [$URL_LOGIN]";
    }

    # extract the <form ...> tag    
    $pg_login =~ /<form(.*)>/mi;
    my $form = $1;

    _debug(2, "analyzing the FORM header: $form");
    my $hash = _parse_html_tag_attributes($form);

    if (!exists $hash->{METHOD}) {
	croak "ERROR! the login form does not contain any METHOD tag.";
	return 0;
    }

    if (uc($hash->{METHOD}) ne "POST") {
	croak "ERROR! the login form does not use the POST method. does not know what to do.";
	return 0;
    }

    # extract the action tag (uri of the login cgi script)
    # and build the URL to which to send the POST request
    my $uri = "".$PROTO.$SERVER.$hash->{ACTION};

    # TODO: build correct $uri

#    if ($uri !~ /\//) {
    # action uri does not contain /, so it's not a complete path
    # we have to extract the root path of $URI_LOGIN, and add $uri to it
#	$URI_LOGIN =~ /\/(.*)\//; 
#	$uri = $URL_LOGIN_HEAD."/";
#    }

    _debug(2, "will send POST request to [$uri]");

    # parse all <input> tags from the <form> block, and build the POST payload with them

    my $payload = "";
    while ($pg_login =~ /<input(.*)>/mgi) {

        $hash = _parse_html_tag_attributes($1);

	my $name  = $hash->{NAME};
	my $value = $hash->{VALUE};

	if ($name) {
	    if ($value) {
		# both name and value are defined
		$payload .= $name."=".$value."&";
	    } else {
		# name defined, but not value. is it one we know?
		if (exists $HTML_INPUT_PPM->{$name}) {
		    $payload .= $name."=".$PPM->{$HTML_INPUT_PPM->{$name}}."&";
		} else {
		    croak "ERROR! login form contains unknown user-set input field [$name] ignoring it.";
		}
	    }
        } else {
	    croak "ERROR! login form contains input field without name. ignoring it.";
	} 
    }

    # truncate the last & at the end of the payload, and replace space with +
    chop $payload;
    $payload =~ s/\s/\+/g;

    _debug(2,"POST's payload is: $payload\n");
    
    $PPM->{html} = $PPM->_http_fetch($uri,'POST',$payload);

    _debug(4,"got HTML account page:\n".$PPM->{html}->as_string());
}

######################################################################
#
#
#   Private HTML tools
#
#
######################################################################

#---------------------------------------------------------------------
#
# _http_fetch($PPM,url,method[,payload])
#
# fetch the page located at $url and return it as a string
# follow location tags, forwards cookies, accepts a payload
# if method is POST
#

sub _http_fetch {
    my($PPM,$url,$method,$payload) = @_;

    if ($method ne 'POST' && $method ne 'GET') {
	croak "don't know how to handle http method [$method] [$url]";
    }

    my $req;
    if ($method eq 'POST') {
	if (!defined $payload) {
	    croak "BUG: method POST requires a payload [$url]";
	} 
	$req = new HTTP::Request('POST', $url,undef,$payload);
    } else {
	$req = new HTTP::Request('GET', $url);
    }

    _debug(1,"retrieving $method [$url]");

    $req->header('Host' => $SERVER);
    $req->header('Connection' => 'Keep-Alive');
    $req->header('Cache-Control' => 'no-cache');
    $req->header('Accept-Language' => 'sv');
    $req->header('Content-Type' => 'application/x-www-form-urlencoded');

    if ($PPM->{referer} ne "") {
	$req->header('Referer' => $PPM->{referer});
    }

    $PPM->{referer} = $url;

    my $res = $PPM->{useragent}->request($req);

    # TODO: if return code != 200, error

    return $res;
}

#---------------------------------------------------------------------
#
# _parse_html_tag_attributes()
#
# take an html tag of the form <tag name1="value1" name2="value2"...>
# and return a hash of the form:
# { NAME1 => value1,
#   NAME2 => value2,
#   ...
# } 
#

sub _parse_html_tag_attributes {
    my $html = shift;
    my $hash = {};

    # assuming the attribute values is between quotes (single or double)
    while ($html =~ /(\w+)=[\"\']([^=]*)[\"\']/g) {
	$hash->{uc($1)} = $2;
    }
    
    return $hash;
}

#---------------------------------------------------------------------
#
# _extract_fund_info() 
#
# extract from the main ppm account html page info about funds
# return a list of hashes describing these funds
#

sub _extract_fund_info {
    my $PPM = shift;
    my $html = $PPM->{html};
    
    # parse html page
    my $root = HTML::TreeBuilder->new; 
    $root->parse($html->content);
    $root->eof();
    $root->elementify;
    
    # did the login failed?
    if ($html->as_string() =~ /Ett fel har intr.*ffat/si ||
	$html->as_string() =~ /Felaktig.*inmatning/si) {
	croak "ERROR: login failed.";
    }

    # WARNING:  THIS CODE IS VERY FRAGILE
    #
    #   and tightly depending on the html page showing
    #   the current account status...

    my $MATCH  = '//table/tr/td/span/span/a';
    my $PATH   = "span, span, td, tr, table, td, tr, table, td, tr, table, body, html";
    my $PARENT = 3;
    
    #
    # find the tables describing each fond
    #
    
    # extract fund names
    my @names = $root->match($MATCH);
    
    # control that we are indeed able to parse this page
    if (scalar @names == 0) {		
	croak "ERROR: did not find any fund name. either the account page's html code as changed or your account is weird looking.";
    }
    
    foreach my $n (@names) {
	my $linea = join(", ",$n->lineage_tag_names());
	if ($linea ne $PATH) {
	    croak "ERROR: unable to recognize html xpath for fund tables:\n got    [$linea]\n wanted [$PATH]\n";
	}
    }
    
    # find the parent <tr> containing all fund information
    my @tables = map( ($_->lineage())[$PARENT], @names);

    #
    # do the actual parsing
    #

    my @funds = ();
    
    # foreach main fund <tr>
    foreach my $t (@tables) {
	my $fund = {};
	$fund->{DATE}        = $PPM->{date};
	$fund->{PNR}         = $PPM->{pnr};

	# find all sub <td>s, containing fund characteristics
	my @tds = $t->find_by_tag_name('td');
	
	my $get_num_value = sub {
	    my $td = shift;
	    my $n = join("",$td->content_list);
	    $n =~ s/[^\d,\.]//gs;	    
	    return $n;
	};
	
	# extract fields
	$fund->{ID}          = &$get_num_value($tds[0]);
	$fund->{SHARE_CNT}   = &$get_num_value($tds[2]);
	$fund->{SHARE_PRICE} = &$get_num_value($tds[3]);
	$fund->{SHARE_VALUE} = &$get_num_value($tds[4]);
	$fund->{CHOSEN_PCT}  = &$get_num_value($tds[5]);
	$fund->{ACTUAL_PCT}  = &$get_num_value($tds[6]);
	
	$fund->{CHOSEN_PCT} = 0
	    if ($fund->{CHOSEN_PCT} eq "");
	
	my $path = $t->xpath();
	my @elems = $t->match($path."/td/span/span/a");
	$fund->{NAME} = join("",map($_->content_list(), @elems));			
	
	push @funds, $fund;
	
	_debug(2, "Identified fund:\n".Dumper($fund));
    }
    
    $PPM->{account} = \@funds;    

    _debug(5,"loaded those funds into PPM object:\n".Dumper($PPM->{account}));
}

_debug(1,"Finance::SE::PPM loaded ok\n");

1;


__END__

=head1 NAME

Finance::SE::PPM - Retrieve a person's account status from the Swedish PPM

=head1 SYNOPSIS

=head1 DESCRIPTION

DO NOT USE THIS MODULE!
IT DOES NOT WORK AND WILL NOT BE FIXED!

---------------

Finance::SE::PPM provides a simple interface to retrieve the state of a
pension saver's account in the Swedish PPM system.

PPM (Premiepensionsmyndigheten) is a Swedish state authority that handles 
a part of the pension savings of the Swedish population, collected through 
taxes on income. PPM gives each pension saver the possibility to choose among 
a wide range of funds in which to place his/her savings. The saver can change 
funds as often as wanted, and at no cost. A pension saver's account gives a 
snapshot of a person's holdings in form of shares in various funds at a given time.

PPM has a web site (www.ppm.nu) where one's account can be monitored and fund 
transactions planned. This web site requires some credentials for login.

Finance::SE::PPM offers an object oriented interface to performing most of the 
fund related transactions available on PPM's web site. It is basically a wrapper 
around PPM's web portal and is designed to be integrated into some more general
Âaccount monitoring and managing tool.

=head1 REQUIREMENTS

Finance::SE::PPM requires the following modules:

    Crypt::SSLeay
    Class::XPath
    HTTP::TreeBuilder

=head1 STATUS

This module is still under development, and should be handled as fragile beta code.
So far only functions related to retrieving an account status are implemented.
Functions to handle fond profile modification are still to come.

=head1 API



=head2 B<new Finance::SE::PPM>(personnummer => $pnr, pincode => $pin, debug => $d)

=over 8

=item B<ARGS>

I<$pnr> the pension saver's personnummer, ie his 12 digit identity code.

I<$pin> his 5 digit pin code.

I<$d> (optional) debug level, where $d is a positive digit. the higher the more verbose. 0 by default.

=item B<RETURN>

a Finance::SE::PPM object.

=item B<DESC>

I<new> creates an object holding all information required to later log onto a person's
PPM account via PPM's website.

=item B<EXAMPLE>

    my $ppm  = new Finance::SE::PPM(personnummer => '197504010666', pincode => '12345');
    my $ppm2 = new Finance::SE::PPM(personnummer => '197504010666', pincode => '12345', debug => 3);

=back



=head2 B<setProxy>($proxy)

=over 8

=item B<ARGS>

I<$proxy> a string of the form "<PROXY_NAME_OR_IP>:<PROXY_PORT>"

=item B<RETURN>

nothing.

=item B<DESC>

Specify which proxy the UserAgent shall use to connect to PPM's web site,
if any. Finance::SE::PPM's user agent uses Crypt::SSLeay which supports
even Squid proxying.

=item B<EXAMPLE>

    $ppm->setProxy("proxy:8080");
    or 
    $ppm->setProxy("192.168.0.1:8080");

=back



=head2 B<fetchAccountStatus>()

=over 8

=item B<ARGS>

none.

=item B<RETURN>

nothing.

=item B<DESC>

Connect to PPM's web site, logon using the credentials given when
creating the PPM object, and import the account status into the
PPM object, to be later used and analysed.

=item B<EXAMPLE>

    $ppm->fetchAccountStatus();

=item B<ERROR>

Die if cannot login onto web site or cannot recognize the page
retrieved. 

=back



=head2 B<getAccountFunds>()

=over 8

=item B<ARGS>

none.

=item B<RETURN>

an array of fund hashes.

=item B<DESC>

Returns an array of fund hashes. Each fund hashs describe the status of the pension saver's ownings
in a given fund. All amounts and prices are given in Swedish crowns. The hash contains the following keys:

=over 4

=item DATE the current date, in format YYYY-MM-DD

=item PNR the saver's personal number

=item ID the fund PPM ID code

=item NAME the fund's name

=item SHARE_CNT the number of shares owned in that fund

=item SHARE_PRICE the value of one share that day

=item SHARE_VALUE the current total value of the pension saver's holdings in that fund that day

=item CHOSEN_PCT the initial percentage of the saver's holdings that should be invested in that fund

=item ACTUAL_PCT the real percentage, taking in account the growths (or losses) in other funds

=back

=item B<EXAMPLE>

    print Dumper($ppm->getAccountFunds);

=back





=head2 B<isChangingFunds>()

=over 8

=item B<ARGS>

none.

=item B<RETURN>

1 if the person is currently changing funds, 0 otherwise.

=item B<DESC>

Check whether the person's account is currently blocked due to a change in the fund profile.
You must have called B<fetchAccountStatus> first.

=item B<EXAMPLE>

    if ($ppm->isChangingFunds) {
        print "you are currently changing fund profile\n";
    }

=back



=head1 EXAMPLE

See the script I<myppmtoday.pl> distributed together with Finance::SE::PPM.
Run './myppmtoday.pl -h' to get some help.

=head1 BUGS

This module has been tested in very few environments. Some bugs might appear
in your environment that the author did not experience. Further more, PPM
may change the layout of their web site, in which case the parsing code
will crash.

In any case, please send a bug report to E<lt>erwan@cpan.orgE<gt>.
Thanks!

=head1 AUTHOR

Erwan Lemmonier, E<lt>erwan@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Erwan Lemmonier

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself. 

=cut
