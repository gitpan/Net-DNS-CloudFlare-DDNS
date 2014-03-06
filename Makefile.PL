use v5.10;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Net::DNS::CloudFlare::DDNS',
    AUTHOR           => q{Peter Roberts <me+dev@peter-r.co.uk>},
    VERSION_FROM     => 'lib/Net/DNS/CloudFlare/DDNS.pm',
    ABSTRACT_FROM    => 'lib/Net/DNS/CloudFlare/DDNS.pm',
    LICENSE          => 'MIT',
    PL_FILES         => {},
    MIN_PERL_VERSION => v5.10,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
	'Moo' => 0.009013,
	'Carp' => 1.20,
	'LWP::UserAgent' => 6.03,
	'JSON::Any' => 1.28,
	'Readonly' => 1.03
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Net-DNS-CloudFlare-DDNS-*' },
);
