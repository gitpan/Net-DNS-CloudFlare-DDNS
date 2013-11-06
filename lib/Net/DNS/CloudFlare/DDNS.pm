package Net::DNS::CloudFlare::DDNS;

use v5.10;
use strict;
use warnings FATAL => 'all';

use Moo;
use Carp;
use LWP::UserAgent;
use JSON::Any;
use Readonly;

=head1 NAME

Net::DNS::CloudFlare::DDNS - Object orientated Dynamic DNS interface
for CloudFlare

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';


=head1 SYNOPSIS

Provides an object orientated interface that can be used to dynamically update 
DNS records on CloudFlare.

    use Net::DNS::CloudFlare::DDNS;

    my $ddns = Net::DNS::CloudFlare::DDNS->new($config);
    my $ddns->update();
    ...

=head1 METHODS

=head2 new

Create a new Dynamic DNS updater

    my $ddns = Net::DNS::CloudFlare::DDNS->new(
        # Required
        user => $cloudflare_user,
        apikey => $cloudflare_api_key,
        zones => $dns_zones,
        # Optional
        verbose => $verbosity
    );

The zones argument must look like the following

    [
        { 
            zone => $zone_name_1,
            domains => [
                $domain_1, ..., $domain_n
            ]
	},
        ...
        { 
            zone => $zone_name_n,
            domains => [
                $domain_1, ..., $domain_n
            ]
	}
    ]

Each domain must be an A record within that zone, use undef for the zonne itself

=head2 update

Updates CloudFlare DNS with the current IP address if
    necessary

    $ddns->update();

=cut

# General Cloudflare API details
Readonly my $CLOUDFLARE_URL =>
    'https://www.cloudflare.com/api_json.html';
Readonly my %CLOUDFLARE_API_PARAMS => (
    request => 'a',
    zone    => 'z',
    user    => 'email',
    key     => 'tkn',
    domain => 'name',
    id => 'id',
    ip => 'content',
    type => 'type',
    ttl => 'ttl'
    ); 

# This request edits a record
Readonly my $CLOUDFLARE_REQUEST_EDIT => 'rec_edit';
Readonly my $RECORD_TYPE => 'A';
Readonly my $TTL => '1';

sub update {
    Readonly my $self => shift;

    # Get current IP address
    Readonly my $ip => $self->_getIp;

    # Don't update unless necessary
    return if defined $self->_ip && $self->_ip eq $ip;

    say 'Updating IPs' if $self->verbose;

    # By default we succeed
    my $succ = 1;
    # Try to update each zone
    for my $zone (@{ $self->_zones }) {
	say "Updating IPs for $zone->{zone}" if $self->verbose;

	for my $dom (@{ $zone->{domains} }) {
	    Readonly my $IP_UPDATE_ERROR => 
		"IP update failed for $dom->{name} in $zone->{zone} at $CLOUDFLARE_URL: ";

	    say "Updating IP for $dom->{name} in $zone->{zone}" if 
		$self->verbose;

	    # Update IP
	    Readonly my $res => $self->_ua->post($CLOUDFLARE_URL, {
		$CLOUDFLARE_API_PARAMS{request} => 
		    $CLOUDFLARE_REQUEST_EDIT,
		$CLOUDFLARE_API_PARAMS{type} => $RECORD_TYPE,
		$CLOUDFLARE_API_PARAMS{ttl} => $TTL,
		$CLOUDFLARE_API_PARAMS{domain} => $dom->{name},
		$CLOUDFLARE_API_PARAMS{zone} => $zone->{zone},
		$CLOUDFLARE_API_PARAMS{id} => $dom->{id},
		$CLOUDFLARE_API_PARAMS{user} => $self->_user,
		$CLOUDFLARE_API_PARAMS{key} => $self->_key,
		$CLOUDFLARE_API_PARAMS{ip} => $ip
					  });
	    
	    if($res->is_success) {
		Readonly my $info =>
		    JSON::Any->jsonToObj($res->decoded_content);
		
		# API call failed
		if($info->{result} eq 'error') {
		    carp $IP_UPDATE_ERROR, $info->{msg};
		    $succ = 0;
		    next;
		}

		say "Updated IP for $dom->{name} in $zone->{zone} successfully"
		    if $self->verbose;
		next;
	    }
	    
	    # HTTP request failed
	    carp $IP_UPDATE_ERROR, $res->status_line;
	    # Mark as failure
	    $succ = 0;
	}
    }

    # Update IP if all updates successful, retry next time otherwise
    $self->_ip($succ ? $ip : undef);
}

=head2 verbose

Accessor for verbose attribute, set to  print status information.

    # Verbosity on
    $ddns->verbose(1);

    # Verbosity off
    $ddns->verbose(undef);

    # Print current verbosity
    say $ddns->verbose;

=cut

has 'verbose' => (
    is      => 'rw',
    default => sub { undef },
    );

=head2 _ip

Accessor for the IP attribute.

    # Set IP
    $ddns->_ip($ip);
    
    # Get IP
    my $up = $dds->_ip;

=cut

=head2 _getIP

Trys to grab the current IP from a number of web services

    # Get current IP
    my $ip = $ddns->_getIP;

=cut

# List of http services returning just an IP
Readonly my @IP_URLS => map { "http://$_" } (
    'icanhazip.com',
    'ifconfig.me/ip',
    'curlmyip.com'
);

sub _getIp {
    Readonly my $self => shift;
    say 'Trying to get current IP' if $self->verbose;

    # Try each service till we get an IP
    for my $serviceUrl (@IP_URLS) {
	say "Trying IP lookup at $serviceUrl" if $self->verbose;

	Readonly my $res => $self->_ua->get($serviceUrl);
	if($res->is_success) {
	    # Chop off the newline
	    my $ip = $res->decoded_content;
	    chomp($ip);

	    say "IP lookup at $serviceUrl returned $ip"
		if $self->verbose;
	    return $ip;
	}

	# log this lookup as failing
	carp "IP lookup at $serviceUrl failed: ", $res->status_line;
    }

    # All lookups have failed
    croak 'Could not lookup IP'
}

=head2 _getDomainIds

Gets and builds a map of domains to IDs for a given zone

    # Get domain IDs
    $ddns->_getDomainIds($zone);

=cut

# This request loads all information on domains in a zone
Readonly my $CLOUDFLARE_REQUEST_LOAD_ALL => 'rec_load_all';

sub _getDomainIds {
    Readonly my $self => shift;
    Readonly my $zone => shift;
    Readonly my $IDS_LOOKUP_ERROR =>
	"Domain IDs lookup for $zone failed: ";

    say "Trying domain IDs lookup for $zone" if $self->verbose;

    # Query CloudFlare
    Readonly my $res => $self->_ua->post($CLOUDFLARE_URL, {
	$CLOUDFLARE_API_PARAMS{request} =>
	    $CLOUDFLARE_REQUEST_LOAD_ALL,
	$CLOUDFLARE_API_PARAMS{zone}    => $zone,
	$CLOUDFLARE_API_PARAMS{key}     => $self->_key,
	$CLOUDFLARE_API_PARAMS{user}    => $self->_user
					 });

     if($res->is_success) {
	Readonly my $info =>
	    JSON::Any->jsonToObj($res->decoded_content);
		
	# Return data unless failure
	unless($info->{result} eq 'error') {
	    # Get a hash of domain => id
	    my %ids = map { 
		$_->{type} eq 'A' 
		    ? ( $_->{name} => $_->{rec_id} ) 
		    : () 
	    } @{ $info->{response}{recs}{objs} };

	    say "Domain IDs lookup for $zone successful"
		if $self->verbose;
	    return %ids;
	}

	# API call failed
	croak $IDS_LOOKUP_ERROR, $info->{msg};
    }

    # HTTP request failed
    croak $IDS_LOOKUP_ERROR, $res->status_line;
}

=head2 BUILD

    Expands subdomains to full domains and attaches domain IDs

=cut

sub BUILD {
    my $self = shift;

    for my $zone (@{ $self->_zones }) {
	Readonly my $name => $zone->{zone};
	Readonly my $domains => $zone->{domains};
	Readonly my %ids => $self->_getDomainIds($name);

	# Decorate domains
	foreach (0 .. $#$domains) {
	    # Expand subdomains to full domains
	    $domains->[$_] = defined $domains->[$_] ?
		"$domains->[$_].$name" :
		$name;

	    my $dom = $domains->[$_];

	    # Attach domain IDs
	    croak "No domain ID found for $dom in $name"
		unless defined $ids{$dom};
	    # Replace with a hash
	    $domains->[$_] = {
		name => $dom,
		id => $ids{$dom}
	    };
	}
    }
}

has '_ip' => (
    is => 'rw',
    default => sub { undef },
    init_arg => undef,
    );

# Read only attributes

# Cloudflare credentials
has '_user' => (
    is       => 'ro',
    required => 1,
    init_arg => 'user'
    );
has '_key' => (
    is       => 'ro',
    required => 1,
    init_arg => 'apikey'
    );

# Cloudflare zones to update
has '_zones' => (
    is => 'ro',
    required => 1,
    init_arg => 'zones'
    );

Readonly my $USER_AGENT => "DDFlare/$VERSION";
has '_ua' => (
    is => 'ro',
    default => sub { 
	Readonly my $ua => LWP::UserAgent->new;
	$ua->agent($USER_AGENT);
	$ua
    },    
    init_arg => undef
    );

=head1 AUTHOR

Peter Roberts, C<< <me+dev at peter-r.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-dns-cloudflare-ddns at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-DNS-CloudFlare-DDNS>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::DNS::CloudFlare::DDNS


You can also look for information at:

=over 4

=item * DDFlare

L<https://bitbucket.org/pwr22/ddflare>

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-DNS-CloudFlare-DDNS>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-DNS-CloudFlare-DDNS>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-DNS-CloudFlare-DDNS>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-DNS-CloudFlare-DDNS/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Peter Roberts.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.


=cut

1; # End of Net::DNS::CloudFlare::DDNS
