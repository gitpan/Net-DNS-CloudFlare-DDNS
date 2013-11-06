#!perl -T
use v5.10;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Net::DNS::CloudFlare::DDNS' ) || print "Bail out!\n";
}

diag( "Testing Net::DNS::CloudFlare::DDNS $Net::DNS::CloudFlare::DDNS::VERSION, Perl $], $^X" );
