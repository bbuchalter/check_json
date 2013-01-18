#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Std;
use LWP::UserAgent;
use JSON 'decode_json';

my $plugin_name = "Nagios check_http_json";
my $VERSION = "1.01";

# getopt module config
$Getopt::Std::STANDARD_HELP_VERSION = 1;

# nagios exit codes
 use constant EXIT_OK            => 0;
 use constant EXIT_WARNING       => 1;
 use constant EXIT_CRITICAL      => 2;
 use constant EXIT_UNKNOWN       => 3;


my $status = EXIT_UNKNOWN;

#parse cmd opts
my %opts;
getopts('vU:t:d:', \%opts);
$opts{t} = 5 unless (defined $opts{t});
if (not (defined $opts{U}) ) {
        print "ERROR: INVALID USAGE\n";
        HELP_MESSAGE();
        exit $status;
}

my $ua = LWP::UserAgent->new;

$ua->agent('Redirect Bot ' . $VERSION);
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($opts{t});

my $response = $ua->get($opts{U});

if ( index($response->header("content-type"), 'application/json') == -1 )
{
  print "Expected content-type to be application/json, got ", $response->header("content-type");
  exit EXIT_CRITICAL;
}


my $json_response;

eval {

  $json_response = decode_json($response->content);
  print "JSON repsonse decoded successfully.";

  $status = EXIT_OK;

  if ($opts{d}) {

    if ( -e $opts{d}) {

      my $hash_import = do $opts{d};
      
      my %attr_check = %{$hash_import};

      my @errors;

      for my $key (sort keys %attr_check) {
          for my $attr (sort keys %{$attr_check{$key}}) {
              my $have = $json_response->{products}{$key}{now}{$attr};
              my $expect = $attr_check{$key}{$attr};
              push @errors, "For key $key, attribute $attr, expected '$expect', but got '$have'"
                  unless $have eq $expect;
          }
      }

      if (@errors) {
          print "Errors:\n", map { "$_\n" } @errors;
          $status = EXIT_CRITICAL;
      }
      else {
          print "Found expected content.";
          $status = EXIT_OK;
      } 
    }
    else {
      print "Unable to find data file $opts{d}";
      $status = EXIT_UNKNOWN;
    }
  }

  exit $status;

} or do {
  print "Unable to decode JSON, invalid response?";
  exit EXIT_CRITICAL;
};

sub HELP_MESSAGE 
{
        print <<EOHELP
        Retrieve an http/s url and checks its application type is application/json and the response content decodes properly into JSON.  
        Optionally verify content is found using data file.
        
        --help      shows this message
        --version   shows version information

        USAGE: $0 -U http://my.url.com [-d sample.data]

        -U          URL to retrieve (http or https)
        -d          absolute path to data file containing hash to find with JSON response (optional)
        -t          Timeout in seconds to wait for the URL to load (default 60)

EOHELP
;
}


sub VERSION_MESSAGE 
{
        print <<EOVM
$plugin_name v. $VERSION
Copyright 2012, Brian Buchalter, http://www.endpoint.com - Licensed under GPLv2
EOVM
;
}
