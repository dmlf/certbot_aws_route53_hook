#!/usr/bin/env perl

=pod
    This script is waiting for values from certbot and will create the needed resource records in route53
=cut

use strict;
use warnings;

my $timeout = 300;
my $route53ZoneId = "Z1EXAMPLE";
my $domain = $ENV{'CERTBOT_DOMAIN'};
my $validation = $ENV{'CERTBOT_VALIDATION'};

sub same_value_in_dns {
  my ($record, $value) = shift @_;
  open my $return, "-|", "dig", "TXT", $record , "+short"
    or die "Dig failed";
  while ( <$return> ){
    $_ eq $value and return 1;
  }
  return 0;
}

local $SIG{ALRM} = sub { die "acme dns check timed out\n" };
alarm $timeout;

print STDERR "Validation key : \"$validation\"\n";
print STDERR "Target domain : \"$domain\"\n";

my $acme_challenge_rr = "_acme-challenge.".$domain;

open my $return, "-|",
    "aws", "route53",
    "change-resource-record-sets",
    "--hosted-zone-id", "$route53ZoneId",
    "--change-batch",
    "{ \"Changes\" : [ {\"Action\": \"UPSERT\", \"ResourceRecordSet\":  {  \"Name\":  \"$acme_challenge_rr\", \"Type\": \"TXT\", \"TTL\": 90, \"ResourceRecords\": [  { \"Value\": \"\\\"$validation\\\"\" } ] }}] }"
  or die "Failed while updating rr in route 53";



select( undef, undef, undef, 6 ) while not ( same_value_in_dns( $acme_challenge_rr, $validation )  );

print STDERR "Dns validation record is ready !";

1;

