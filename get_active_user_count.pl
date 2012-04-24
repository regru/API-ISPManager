#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use API::ISPManager;

#
# Script for get active user count
#

die "Params required: host / username / password\n" unless scalar @ARGV == 3;

my $host     = $ARGV[0];
my $login    = $ARGV[1];
my $password = $ARGV[2];

$API::ISPManager::DEBUG = '';

my %connection_params = (
    username => $login,
    password => $password,
    host     => $host,
    path     => 'manager',
);


my $result = API::ISPManager::user::active_user_count( {
    %connection_params,   
} );

print "$result\n";


