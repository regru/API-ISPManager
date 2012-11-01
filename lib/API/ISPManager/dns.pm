package API::ISPManager::dns;

use strict;
use warnings;

use API::ISPManager;

sub list {
    my $params = shift;

    my $server_answer = API::ISPManager::query_abstract(
        params      => $params,
        func        => 'domain',
        fake_answer => shift,
    );

    #if ( $server_answer && $server_answer->{elem} && ref $server_answer->{elem} eq 'HASH' ) {
    #    return { data =>  $server_answer->{elem} };
    #}

    return $server_answer;
}

sub get {
    my $params = shift;
    my $server_answer = API::ISPManager::query_abstract(
        params      => $params,
        func        => 'domain.edit',
        allowed_fields => [qw(host path allow_http     owner elid mx ns ip name)], 
        fake_answer => shift,
    );
    return $server_answer;
   
}

sub edit {
    my $params = shift;

     my $server_answer = API::ISPManager::query_abstract(
        params      => { %$params, sok => 'yes' },
        func        => 'domain.edit',
        allowed_fields => [qw(host path allow_http sok   owner elid mx ns ip)], 
        fake_answer => shift,
    );
    return $server_answer;
   
}

sub sublist {
    my $params = shift;

     my $server_answer = API::ISPManager::query_abstract(
        params      => $params,
        func        => 'domain.sublist',
        allowed_fields => [qw(host path allow_http  elid)], 
        fake_answer => shift,
        parser_params => { ForceArray => ['name'] }, 
    );

    unless ( $server_answer ) {
        return {
            error => {
                code => 0,
                obj  => "No answer from server with ISP Panel",
            }
        }
    }

    for my $el ( @{$server_answer->{elem}} ) {
        $el->{name} = $el->{name}->[0];
    }

    return $server_answer;
   
}

sub sublist_get {
    my $params = shift;

     my $server_answer = API::ISPManager::query_abstract(
        params      => $params,
        func        => 'domain.sublist.edit',
        allowed_fields => [qw(host path allow_http   plid elid)], 
        fake_answer => shift,
    );
    return $server_answer;
   
}

sub sublist_edit {
    my $params = shift;

     my $server_answer = API::ISPManager::query_abstract(
        params      => { %$params, sok => 'yes' },
        func        => 'domain.sublist.edit',
        allowed_fields => [qw(host path allow_http sok   owner plid elid name sdtype addr prio wght port)], 
        fake_answer => shift,
    );
    return $server_answer;
   
}

sub sublist_delete {
    my $params = shift;

     my $server_answer = API::ISPManager::query_abstract(
        params      => $params,
        func        => 'domain.sublist.delete',
        allowed_fields => [qw(host path allow_http sok   plid elid)],
        fake_answer => shift,
    );
    return $server_answer;
   
}



1;
