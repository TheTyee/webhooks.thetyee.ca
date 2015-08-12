#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::JSON;
use Modern::Perl '2013';
use Try::Tiny;
use Data::Dumper;
use WebHooks::Schema;
use Support::Schema;


my $config = plugin 'JSONConfig';
my $json   = Mojo::JSON->new;


# Get a UserAgent
my $ua = Mojo::UserAgent->new;

# WhatCounts setup
my $API        = $config->{'wc_api_url'};
my $wc_list_id = $config->{'wc_listid'};
my $wc_realm   = $config->{'wc_realm'};
my $wc_pw      = $config->{'wc_password'};
my $secret     = $config->{'tw_secret'};

    my %args = (
        r => $wc_realm,
        p => $wc_pw,
    );

my %wc_to_db;

helper dbh => sub {
    my $schema = WebHooks::Schema->connect( $config->{'pg_dsn'},
        $config->{'pg_user'}, $config->{'pg_pass'}, );
    return $schema;
};


helper dbhsupport => sub  {
    my $schema = Support::Schema->connect( $config->{'pg_dsn'},
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
        form_name    => $form->{'Name'},
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
    my $self      = shift;
    my $hook      = shift;
    my $handshake = 'none';
    $handshake = $hook->{'HandshakeKey'};
    my $auth;
    $auth = $handshake eq $config->{'wufoo_handshake'} ? 'authorized' : '';
    $self->app->log->debug(
        'Unauthorzied access attempt: ' . Dumper( $hook ) )
        if !$auth;
    return $auth;
};

any '/wufoo' => sub {
    my $self = shift;
    my $hook = $self->req->params->to_hash;
    return $self->render( { data => '', status => '401' } )
        unless $self->authorized( $hook );
    my $subscriber = $self->parse_webhooks_data( $hook );
    my $result     = $self->find_or_new( $subscriber );
    $self->app->log->debug( Dumper( $subscriber ) );
    $self->respond_to( any => { 'data' => '', status => 200 }, );
};

get '/' => sub {
    my $c = shift;
  $c->render(text => 'Hello World!');

};

post '/recurly' => sub {
    
    my $self = shift;
    my $post = shift;
        my $dom   = $self->req->dom;
        my $body = $self->req->body;
    use XML::Simple;
    my $xs = XML::Simple->new();
    my $xms = $xs->XMLin($body, KeepRoot => 1);
    my $hooktype = ( keys( $xms))[0] ;
    my $lasttrans;
    my $email = $xms->{$hooktype}{account}{email};
    my $builder_plan;
    my $amount;
        
    
    my %update_params;
    $update_params{'email'} = $email;
    if ($hooktype eq 'new_subscription_notification') {
        $update_params{'custom_builder_last_trans_date'} = $xms->{$hooktype}{subscription}{current_period_started_at}{content};
        $update_params{'custom_builder_plan'} = $xms->{$hooktype}{subscription}{plan}{plan_code};
        $update_params{'custom_builder_level'} = ($xms->{$hooktype}{subscription}{total_amount_in_cents}{content} / 100);
        $update_params{'custom_builder'} = 1;
    
    
    } elsif ($hooktype eq 'renewed_subscription_notification') {
        $update_params{'custom_builder_last_trans_date'} = $xms->{$hooktype}{subscription}{current_period_started_at}{content};
        $update_params{'custom_builder_level'} = ($xms->{$hooktype}{subscription}{total_amount_in_cents}{content} / 100);
        $update_params{'custom_builder_plan'} = $xms->{$hooktype}{subscription}{plan}{plan_code};
        $update_params{'custom_builder'} = 1;

        
        
    } elsif ($hooktype eq 'updated_subscription_notification') {
        $update_params{'custom_builder_level'} = ($xms->{$hooktype}{subscription}{total_amount_in_cents}{content} / 100);
        $update_params{'custom_builder'} = 1;
        $update_params{'custom_builder_last_trans_date'} = $xms->{$hooktype}{subscription}{current_period_started_at}{content};
        $update_params{'custom_builder_plan'} = $xms->{$hooktype}{subscription}{plan}{plan_code};


        
     } elsif ($hooktype eq 'expired_subscription_notification' || $hooktype eq 'canceled_subscription_notification') {
        $update_params{'custom_builder_last_trans_date'} = $xms->{$hooktype}{subscription}{canceled_at}{content};        
        $update_params{'custom_builder_cancelled_date'} = $xms->{$hooktype}{subscription}{canceled_at}{content};
        $update_params{'custom_builder_plan'} = 'cancelled';

    } else {
            $self->app->log->debug('transtype is ' . $hooktype);    
            $self->app->log->debug( 'no webhooks of use here' );
          return $self->render(text => 'Nothing to update', status => '204');
              
    }
    

    
    # find the record
       my $search_args = {
        %args,
        cmd   => 'find',
        email => $email,
    };
    my $search; my $result;
    
    # Get the subscriber record, if there is one already
    my $s = $ua->post( $API => form => $search_args );
    if ( my $res = $s->success ) {
        $search = $res->body;
    }
    else {
        my ( $err, $code ) = $s->error;
        $result = $code ? "$code response: $err" : "Connection error: $err";
    }
#get a string of comma separated keys then ^ and values like whatcounts wants    
    my $updatecsv;
    $updatecsv = join( ',', (keys(%update_params))) . '^';
    my $count = 0;
    foreach (keys(%update_params)) {
            if  ($count > 0 ) { $updatecsv .= ','};
            $updatecsv .= $update_params{$_};
            $count++;
        }
    
    
    if ($search) {
           $self->app->log->debug('updating now - search exists');    

     my $update = {
        %args,
        cmd =>              'update',
        list_id               => $wc_list_id,
        format                => '2',
        identity_field        => 'email',
        data => $updatecsv
    };
    my $tx = $ua->post( $API => form => $update );
    if ( my $res = $tx->success ) {
                           $self->app->log->debug(' Successful whatcounts UA tx dump: ' .Dumper($tx));    

        $result = $res->body;
                   $self->app->log->debug('update success');    

    }
    else {
        my ( $err, $code ) = $tx->error;
        $result = $code ? "$code response: $err" : "Connection error: $err";
                           $self->app->log->debug('update failure');    

    }
    
    $self->app->log->debug('Adding to local db');
    
    my $subscriber = shift;
    my $dbhsupport       = $self->dbhsupport();
    my $result;
    try {
        $result = $dbhsupport->txn_do(
            sub {
                my $rs = $dbhsupport->resultset( 'Transaction' )
                    ->find( { 'email' => $email } );
                if ( $rs->in_storage ) {
                    $self->app->log->debug('found email in local db');    
    my %recurlyupdate;
  
  if ($update_params{'custom_builder_last_trans_date'}) {
    $recurlyupdate{"trans_date"} = $update_params{'custom_builder_last_trans_date'};
  }
  if ( $update_params{'custom_builder_level'}) {
    $recurlyupdate{"amount_in_cents"} = $update_params{'custom_builder_level'} * 100;
  }
  
   if ( $update_params{'custom_builder_plan'}) {
    $recurlyupdate{"plan_name"} = $update_params{'custom_builder_plan'};
  }
  
  if ($update_params{'custom_builder_cancelled_date'}) {
    $recurlyupdate{"plan_name"} = "cancelled"
  }
                      
                   $rs->update(\%recurlyupdate);
                }
            }
        );
    }
    catch {
        $self->app->log->debug( $_ );
    };
#    $self->app->log->debug( 'return from db update :' . Dumper($result) );
    if ($result) {
        $self->app->log->debug('success adding to local db');
    }
    
    
    } # search exists test
    
    
# $self->app->log->debug( Dumper( $xms ) );
        $self->app->log->debug('transtype is ' . $hooktype);    
        $self->app->log->debug("return from WC search \n " . $search);    
        $self->app->log->debug("return from WC update \n " . Dumper( $result));
#        $self->app->log->debug("update csv for whatcounts" . $updatecsv);    

    $self->respond_to(   
        any  => {data => '', status => 204}
    );


    
};


app->secret( $config->{'app_secret'} );
app->start;
