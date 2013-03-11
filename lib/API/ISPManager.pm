package API::ISPManager;

use strict;
use warnings;
use lib qw(../..);

use Exporter::Lite;
use LWP::UserAgent;
#use XML::LibXML;
use XML::Simple;
use Data::Dumper;

# Main packages
use API::ISPManager::ip;
use API::ISPManager::user;
use API::ISPManager::domain;
use API::ISPManager::mailbox;

# Addition packages
use API::ISPManager::backup;
use API::ISPManager::db;
use API::ISPManager::preset;
use API::ISPManager::stat;
use API::ISPManager::services;
use API::ISPManager::ftp;
use API::ISPManager::misc;
use API::ISPManager::file;

# VDSManager
use API::ISPManager::vds;
use API::ISPManager::diskpreset;
use API::ISPManager::vdspreset;

# BillManager
use API::ISPManager::software;
use API::ISPManager::order;

our $VERSION   = 0.08;
our $DEBUG     = '';

=head1 NAME

API::ISPManager - interface to the ISPManager Hosting Panel API ( http://ispsystem.com )

=head1 SYNOPSIS

 use API::ISPManager;
 
 my $connection_params = {
    username => 'username',
    password => 'qwerty',
    host     => '11.22.33.44',
    path     => 'manager',
 };

 ### Get all panel IP
 my $ip_list = API::ISPManager::ip::list( $connection_params );

 unless ($ip_list && ref $ip_list eq 'ARRAY' && scalar @$ip_list) {
    die 'Cannot get ip list from ISP';
 }

 my $ip  = $ip_list->[0];
 my $dname  = 'perlaround.ru';

 my $client_creation_result = API::ISPManager::user::create( {
    %{ $connection_params },
    name      => 'user_login',
    passwd    => 'user_password',
    ip        => '11.11.22.33', 
    preset    => 'template_name',
    domain    => $dname,
 });

 # Switch off account:
 my $suspend_result = API::ISPManager::user::disable( {
    %{ $connection_params },
    elid => $use_login,
 } );

 unless ( $suspend_result ) {
    die "Cannot  suspend account";
 }



 # Switch on account
 my $resume_result = API::ISPManager::user::enable( {
    %{ $connection_params },
    elid => $user_login,
 } );

 unless ( $resume_result ) {
    die "Cannot  suspend account";
 }



 # Delete account
 my $delete_result = API::ISPManager::user::delete( {
    %{ $connection_params },
    elid => $login,
 } );

 unless ( $delete_result ) {
    die "Cannot delete account";
 }


=cut

# Last raw answer from server 
our $last_answer = ''; 

# Public!
sub is_ok {
    my $answer = shift;

    return '' unless $answer && ref $answer eq 'HASH' && $answer->{success};
}


sub get_error {
    my $answer = shift;

    return '' if is_ok($answer); # ok == no error

    return Dumper( $answer->{error} );
}

# Get data from @_
sub get_params {
    my @params = @_;

    if (scalar @params == 1 && ref $params[0] eq 'HASH' ) {
        return { %{ $params[0] } };
    } else {
        return { @params };
    }
}

# Make query string
# STATIC(HASHREF: params)
sub mk_query_string {
    my $params = shift;

    return '' unless $params &&
        ref $params eq 'HASH' && %$params ;

    my $result = join '&', map { "$_=$params->{$_}" } sort keys %$params;
    warn $result if $DEBUG;

    return $result;
}

# Kill slashes at start / end string
# STATIC(STRING:input_string)
sub kill_start_end_slashes {
    my $str = shift;

    for ($str) {
        s/^\/+//sgi;
        s/\/+$//sgi;
    }
    
    return $str;
}

# Make full query string (with host, path and protocol)
# STATIC(HASHREF: params)
# params:
# host*
# path
# allow_http
# param1
# param2 
# ...
sub mk_full_query_string {
    my $params = shift;

    return '' unless
        $params               &&
        ref $params eq 'HASH' &&
        %$params              &&
        $params->{host};

    my $host       = delete $params->{host};
    my $path       = delete $params->{path}        || '';
    my $allow_http = delete $params->{allow_http}  || '';

    unless ($path) {
        $path = 'manager';
    }

    $path = kill_start_end_slashes($path);
    $host = kill_start_end_slashes($host);

    my $query_path = ( $allow_http ? 'http' : 'https' ) . "://$host/$path/ispmgr?";

    return %$params ? $query_path . mk_query_string($params) : '';
}


# Make request to server and get answer
# STATIC (STRING: query_string)
sub mk_query_to_server {
    my $query_string = shift;

    return '' unless $query_string;
    warn "Query string: $query_string\n" if $DEBUG;

    my $ua = LWP::UserAgent->new;
    $ua->agent("Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)");
    # Don`t working without this string!

    # Èãíîðèðóåì âåðèôèêàöèþ õîñòîâ
    $ua->ssl_opts( verify_hostname => 0 ) if $ua->can('ssl_opts');

    my $response = $ua->get($query_string);

    if ($response->is_success) {
        my $content = $response->content;

        if ($response->header('content-type') eq 'text/xml') {
            # allow only XML answers
            if ($content && $content =~ /^<\?xml version="\d\.\d" encoding=".*?"\?>/s) {
                warn $content if $DEBUG;
                return $content;
            } else {
                $last_answer = { error => 'malformed xml ' . $response->as_string };
                return '';
            }
        } else {
            
            $last_answer = { error => 'bad content-type ' . $response->as_string };
            return '';
        }
    } else {
        $last_answer = { error => 'mk_query_to_server is not success ' . $response->as_string };
        return '';
    }
}

# Parse answer
# STATIC(HASHREF: params)
# params:
#  STRING: answer
#  HASHREF: xml_parser_params)
sub parse_answer {
    my %params = @_;

    my $answer_string =
        $params{answer};
    my $parser_params =
        $params{parser_params} || { };

    $last_answer = {};
    return '' unless $answer_string;

    my $deparsed = XMLin( $answer_string, %$parser_params );
    warn Dumper $deparsed if $DEBUG;
    
    $last_answer = $deparsed;
    return $deparsed ? $deparsed : '';
}

# Get + deparse
# STATIC(STRING: query_string)
sub process_query {
    my %params = @_;

    my $query_string      = $params{query_string};
    my $xml_parser_params = $params{parser_params} || '';
    my $fake_answer       = $params{fake_answer} || '';

    if ( ! $query_string ) {
        $last_answer = { error => 'no query_string specified!' };
        
        return '';
    }
    
    my $answer = $fake_answer ? $fake_answer : mk_query_to_server($query_string);
    warn $answer if $answer && $DEBUG;

    return $answer ?
        parse_answer(
            answer        => $answer,
            parser_params => $xml_parser_params
        ) : '';
}

# Filter hash
# STATIC(HASHREF: hash, ARRREF: allowed_keys)
# RETURN: hashref only with allowed keys
sub filter_hash {
    my ($hash, $allowed_keys) = @_;

    return unless ref $hash eq 'HASH' &&
        ref $allowed_keys eq 'ARRAY';
    
    my $new_hash = { };

    foreach my $allowed_key (@$allowed_keys) {
        if (exists $hash->{$allowed_key}) {
            $new_hash->{$allowed_key} = $hash->{$allowed_key};
        }
    }

    return $new_hash;
}

# Get access key, time to live -- 30 minutes
# STATIC(HASHREF: params_hash)
# params_hash:
# - all elements from mk_full_query_string +
# - username*
# - password*
sub get_auth_id {
    my %params_raw = @_;

    warn 'get_auth_id params: ' . Dumper(\%params_raw)  if $DEBUG;

    my $params = filter_hash(
        \%params_raw,
        [ 'host', 'path', 'allow_http', 'username', 'password' ]
    );

    # Check this sub params
    unless ($params->{username} && $params->{password}) {
        return '';
    }

    
    my $query_string = mk_full_query_string( {
        %$params, 
        func     => 'auth',
        out      => 'xml',
    } );

    return '' unless $query_string;
    
    warn $query_string if $DEBUG;

    my $xml = process_query( query_string => $query_string);

    if ($xml) {
        my $error_node = exists $xml->{authfail};
        return '' if $error_node;

        return $xml->{auth}->{id};
    } else {
        return '';
    }
}

# Wrapper for "ref" on undef value, without warnings :)
# Possible very stupid sub :)
# STATIC(REF: our_ref)
sub refs {
    my $ref = shift;

    return '' unless $ref;

    return ref $ref;
}

# INTERNAL!!! Check server answer result
# STATIC(data_block)
sub is_success {
    my $data_block = shift;

    if ( ref $data_block eq 'HASH' && ! $data_block->{error} && $data_block->{data} ) {
        return 1;
    } else {
        return '';
    }
}

# Get data from server answer
# STATIC(data_block)
sub get_data {
    my $data_block = shift;

    unless ( is_success($data_block) ) {
        return '';
    }

    return $data_block->{data};
}

sub user_su {
    my %params_raw = @_;

    return 1  unless $params_raw{user_su};
    return '' unless $params_raw{auth};

    warn 'user_su params: ' . Dumper(\%params_raw)  if $DEBUG;

    my $params = filter_hash(
        \%params_raw,
        [ 'host', 'path', 'allow_http', 'auth' ]
    );

    my $query_string = mk_full_query_string( {
        %$params, 
        func => 'user.su',
        elid => $params_raw{user_su},
        out  => 'xml',
    } );

    return '' unless $query_string;

    warn $query_string if $DEBUG;

    my $xml = process_query( query_string => $query_string);

    return '' unless ref $xml eq 'HASH' && !exists $xml->{error};
    return 1;
}

# list all users
# all params derived from get_auth_id
sub query_abstract {
    my %params = @_;

    my $params_raw  = $params{params};
    my $func_name   = $params{func};
    my $fake_answer = $params{fake_answer} || '';

    warn 'query_abstract ' . Dumper( \%params ) if $DEBUG;

    unless ($params_raw && $func_name) {
        $last_answer = { error => '"func" && "params" not specified!' };
        
        return '';
    } 

    my $allowed_fields = $params{allowed_fields} || [ 'host', 'path', 'allow_http' ];
    # TODO ÑÐ´ÐµÐ»Ð°Ñ‚ÑŒ ÑÑ†ÐµÐ¿ÐºÑƒ Ð¼Ð°ÑÑÐ¸Ð²Ð¾Ð² Ñ‚ÑƒÑ‚!!!!

    my $xml_parser_params = $params{parser_params};

    my $auth_id = $fake_answer  ? '112323' : get_auth_id( %$params_raw );
    warn "Auth_id: $auth_id\n" if $DEBUG;

    unless ( user_su( %{{ %$params_raw, auth => $auth_id, }} ) ) {
        $last_answer = { error => '"user_su" failed' };
        
        return '';
    }

    if ($auth_id or $func_name eq 'ftp') { # ftp hacked by authinfo
        my $params = filter_hash( $params_raw, $allowed_fields);
    
        my $query_string = mk_full_query_string( {
            ( $func_name eq 'ftp' ? ( ) : ( auth => $auth_id ) ), # for ftp auth not used, only authinfo
            func => $func_name,
            out  => 'xml',
            %$params,
        } );

        warn Dumper $query_string if $DEBUG;

        return process_query(
            query_string  => $query_string,
            parser_params => $xml_parser_params,
            fake_answer   => $fake_answer,
        );

        # 
        # TODO add this check here 
        #  if ( $server_answer && $server_answer->{elem} && ref $server_answer->{elem} eq 'HASH' ) {
        #        return { data =>  $server_answer->{elem} };
        #    }
        #

    } else {
        warn "auth_id not found or func type not ftp" if $DEBUG;
        
        $last_answer = { error => 'auth_id not found or func type not ftp' };
        
        return '';
    }
}

1;
