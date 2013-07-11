#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::JSON;
use Modern::Perl '2013';
use Try::Tiny;
use Data::Dumper;
use WebHooks::Schema;

my $config = plugin 'JSONConfig';
my $json   = Mojo::JSON->new;

helper dbh => sub {
    my $schema = WebHooks::Schema->connect( $config->{'pg_dsn'},
        $config->{'pg_user'}, $config->{'pg_pass'}, );
    return $schema;
};

helper find_or_new => sub {
    my $self       = shift;
    my $subscriber = shift;
    my $dbh        = $self->dbh();
    my $result;
    try {
        $result = $dbh->txn_do(
            sub {
                my $rs = $dbh->resultset( 'Wufoo' )
                    ->find_or_new( { %$subscriber, } );
                unless ( $rs->in_storage ) {
                    $rs->insert;
                }
            }
        );
    }
    catch {
        $self->app->log->debug( $_ );
    };
    return $result;
};

helper parse_webhooks_data => sub {
    my $self  = shift;
    my $post  = shift;
    my $field = $json->decode( $post->{'FieldStructure'} );
    my $form  = $json->decode( $post->{'FormStructure'} );
    my $data  = {
        entry_id     => $form->{'Hash'} . '-' . $post->{'EntryId'},
        date_created => $post->{'DateCreated'},
        form_url     => $form->{'Url'},
        form_data    => $json->encode( $post ),
        ip_address   => $post->{'IP'},
        form_name   => $form->{'Name'},
    };
    for my $value ( @{ $field->{'Fields'} } ) {
        if ( $value->{'Type'} eq 'email' ) {

            $data->{'email'} = $post->{ $value->{'ID'} };
        }
        elsif ($value->{'Title'} eq 'Stay informed'
            && $value->{'Type'} eq 'radio' )
        {
            $data->{'subscription'} = $post->{ $value->{'ID'} };
        }
    }
    return $data;
};

helper authorized => sub {
    my $self = shift;
    my $hook = shift;
    my $handshake = $hook->{'HandshakeKey'};
    my $auth;
    $auth = $handshake eq $config->{'wufoo_handshake'} ? 'authorized' : '';
    $self->app->log->debug('Unauthorzied access attempt: ' . Dumper( $hook ) ) if !$auth;
    return $auth;
};

any '/wufoo' => sub {
    my $self       = shift;
    my $hook       = $self->req->query_params->to_hash;
    return $self->render({ data => '', status => '401'}) unless $self->authorized( $hook );
    my $subscriber = $self->parse_webhooks_data( $hook );
    my $result     = $self->find_or_new( $subscriber );
    $self->app->log->debug( Dumper( $subscriber ) );
    $self->respond_to(
        any => { 'data' => '', status => 200 },
    );
};

app->secret( $config->{'app_secret'} );
app->start;
