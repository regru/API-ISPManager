package API::ISPManager::domain;

use strict;
use warnings;

use API::ISPManager;

sub list {
    my $params = shift;

    my $result = API::ISPManager::query_abstract(
        params => $params,
        func   => 'wwwdomain'
    );
    my $true_result = {};

    return $true_result unless ref $result eq 'HASH' && $result->{elem};
    $result = $result->{elem};
    $true_result->{ $result->{name} } = $result if $result->{name};
    $true_result = $result unless keys %$true_result;

    return $true_result;
}

# Create domain
sub create {
    my $params = shift;

    my $result = API::ISPManager::query_abstract(
        params => { %$params, sok => 'yes' }, # чтобы создание разрешить
        func   => 'wwwdomain.edit', 
        allowed_fields => [  qw( host path allow_http     domain alias sok name owner ip docroot cgi php ssi ror ssl sslport admin ) ],
    );

    $API::ISPManager::last_answer = $result;

    if ($result && $result->{ok}) {
        return 1;
    } else {
        return '';
    }
}

# Edit domain data
sub edit {

}

# Delete domain from panel
# webdomain = on/off
# maildomain = on/off
sub delete {
    my $params = shift;
    
    my $result = API::ISPManager::query_abstract(
        params => { %$params, sok => 'ok' }, # чтобы удаление разрешить
        func   => 'domain.delete',
        allowed_fields => [  qw( host path allow_http  sok elid webdomain maildomain extop user_su manager ) ],
    );

    $API::ISPManager::last_answer = $result;

    if ($result && $result->{ok}) {
        return 1;
    } else {
        return '';
    }
}

package API::ISPManager::email_domain;

use API::ISPManager;

sub list {
    my $params = shift;

    return API::ISPManager::query_abstract(
        params => $params,
        func   => 'emaildomain'
    );
}

# Create domain
sub create {

}

# Edit domain data
sub edit {

}

# Delete domain from panel
sub delete {

}

1;
