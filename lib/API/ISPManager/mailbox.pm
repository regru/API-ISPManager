package API::ISPManager::mailbox;

use strict;
use warnings;

use API::ISPManager;

sub list {
    my $params = shift;

    return API::ISPManager::query_abstract(
        params => $params,
        func   => 'email'
    );
}

# get mailbox details
sub get {
    my $params = shift;

    my $result = API::ISPManager::query_abstract(
        params => $params,
        func   => 'email.edit', 
        allowed_fields => [  qw( host path allow_http  elid name domain aliases passwd confirm quota forward rmlocal greylist spamassassin note ) ],
    );

    $API::ISPManager::last_answer = $result;

    if ( ref $result ) {
        # чтобы сразу можно было передавать в edit
        for my $key ( qw(forward aliases note) ) {
            $result->{$key} = '' if ref $result->{$key} eq 'HASH';
        }
    }

    return $result;

}

# Create domain
sub create {
    my $params = shift;

    my $result = API::ISPManager::query_abstract(
        params => { %$params, sok => 'yes' }, # чтобы создание разрешить
        func   => 'email.edit', 
        allowed_fields => [  qw( host path allow_http  sok name domain aliases passwd confirm quota forward rmlocal greylist spamassassin note ) ],
    );

    $API::ISPManager::last_answer = $result;

    if ($result && $result->{ok}) {
        return 1;
    } else {
        return '';
    }
}

# Edit email data
sub edit {
    my $params = shift;

    my $result = API::ISPManager::query_abstract(
        params => { %$params, sok => 'yes' },
        func   => 'email.edit', 
        allowed_fields => [  qw( host path allow_http  elid sok name domain aliases passwd confirm quota forward rmlocal greylist spamassassin note ) ],
    );

    $API::ISPManager::last_answer = $result;

    if ($result && $result->{ok}) {
        return 1;
    } else {
        return '';
    }
}

# Delete email from panel
sub delete {

}

1;
