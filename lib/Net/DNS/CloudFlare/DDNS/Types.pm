package Net::DNS::CloudFlare::DDNS::Types;
# ABSTRACT: Types for Net::DNS::CloudFlare::DDNS

use Modern::Perl '2012';
use autodie      ':all';
no  indirect     'fatal';
use namespace::autoclean;

use Type::Library -base;
# Theres a bug about using undef as a hashref before this version
use Type::Utils 0.039_12 -all;

our $VERSION = '0.06_1'; # TRIAL VERSION

class_type 'CloudFlare::Client';
class_type 'LWP::UserAgent';

1; # End of Net::DNS::CloudFlare::DDNS::Types

__END__

=pod

=encoding UTF-8

=head1 NAME

Net::DNS::CloudFlare::DDNS::Types - Types for Net::DNS::CloudFlare::DDNS

=head1 VERSION

version 0.06_1

=head1 SYNOPSIS

Provides types used in Net::DNS::CloudFlare::DDNS

    use Net::DNS::CloudFlare::DDNS::Types 'CloudFlareClient';

=head1 AUTHOR

Peter Roberts <me+dev@peter-r.co.uk>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Peter Roberts.

This is free software, licensed under:

  The MIT (X11) License

=cut
