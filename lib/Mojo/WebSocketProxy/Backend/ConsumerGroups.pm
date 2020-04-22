package Mojo::WebSocketProxy::Backend::ConsumerGroups;

use strict;
use warnings;

use Math::Random::Secure;
use Mojo::Redis2;
use IO::Async::Loop::Mojo;
use Data::UUID;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use Syntax::Keyword::Try;

use parent qw(Mojo::WebSocketProxy::Backend);

no indirect;

## VERSION

__PACKAGE__->register_type('consumer_groups');


use constant RESPONSE_TIMEOUT => $ENV{PRPC_QUEUE_RESPONSE_TIMEOUT} // 300;

sub new {
    my ($class, %args) = @_;
    return  bless \%args, $class;
}

sub loop {
    my $self = shift;
    return $self->{loop} //= do {
        require IO::Async::Loop::Mojo;
        local $ENV{IO_ASYNC_LOOP} = 'IO::Async::Loop::Mojo';
        IO::Async::Loop->new;
    };
}

sub pending_requests {
    shift->{pending_requests} //= {}
}

sub redis {
    my $self = shift;
    return $self->{redis} //= Mojo::Redis2->new(url => $self->{redis_uri});
}

sub whoami {
    my $self = shift;

    return $self->{whoami} if $self->{whoami};

    Math::Random::Secure::srand() if Math::Random::Secure->can('srand');
    $self->{whoami} = Data::UUID->new->create_str();

    return $self->{whoami};
}

sub wait_for_messages {
    my $self = shift;
    $self->{already_waiting} //= 
    $self->redis->subscribe([$self->whoami], sub {
        $self->redis->on('message', sub {
            my ($redis, $raw_message) = @_;
            my $message = decode_json_utf8($raw_message);
            
            my $completion_future = $self->pending_requests->{$message->{original_id}};
            
            if ($completion_future) {
                $completion_future->done($message);
                delete $self->pending_requests->{$message->{original_id}};
            }
        });
    });
}

sub call_rpc {
    my ($self, $c, $req_storage) = @_;
    
    # make sure that we are already waiting for messages
    # calling this sub multiple time is safe, it will be executed once
    $self->wait_for_messages();
    my $request_data = $self->prepare_request($c,$req_storage);

    my $msg_type = $req_storage->{msg_type} ||= $req_storage->{method};

    my $rpc_response_cb = $self->get_rpc_response_cb($c, $req_storage);
    my $before_get_rpc_response_hooks = delete($req_storage->{before_get_rpc_response}) || [];
    my $after_got_rpc_response_hooks  = delete($req_storage->{after_got_rpc_response})  || [];
    my $before_call_hooks             = delete($req_storage->{before_call})             || [];
    my $rpc_failure_cb                = delete($req_storage->{rpc_failure_cb})          || 0;

    foreach my $hook (@$before_call_hooks) { $hook->($c, $req_storage) }

    $self->redis->_execute(xadd => 'XADD' => ('rpc_requests', '*', $request_data->@*), sub {
        my ($redis, $error, $message_id) = @_;
        
        my $f = $self->loop->new_future();
        $self->pending_requests->{$message_id} = $f;
        
        Future->wait_any(
            $self->loop->timeout_future(after => RESPONSE_TIMEOUT),
            $f
        )->then(sub {
            my ($message) = @_;
            
            foreach my $hook (@$before_get_rpc_response_hooks) { $hook->($c, $req_storage) }
            
            return Future->done unless $c and $c->tx;
            
            my $api_response;
            my $result;
            
            try {
                $result = MojoX::JSON::RPC::Client::ReturnObject->new(rpc_response => decode_json_utf8($message->{response}));
                foreach my $hook (@$before_get_rpc_response_hooks) { $hook->($c, $req_storage, $result) }
                $api_response = $rpc_response_cb->($result->result);
            } catch {
                    my $error = $@;
                    $rpc_failure_cb->($c, $result, $req_storage) if $rpc_failure_cb;
                    $api_response = $c->wsp_error($msg_type, 'WrongResponse', 'Sorry, an error occurred while processing your request.');
            };
                
            $c->send({json => $api_response}, $req_storage);
            
            return Future->done();
        })->catch(sub {
            my $error = shift;
            delete $self->pending_requests->{$message_id};    
            my $api_response;
            
            if ($error eq 'Timeout') {
                $api_response = $c->wsp_error($msg_type, 'RequestTimeout', 'Request is timed out.');
            } else {
                $api_response = $c->wsp_error($msg_type, 'WrongResponse', 'Sorry, an error occurred while processing your request.');
            }
            
            $c->send({json => $api_response}, $req_storage);
            
        })->retain;
    });
    
    return;
}

sub send_request {
    my ($self, $request_data) = @_;

    my $f = $self->loop->new_future;
    $self->redis->_execute(xadd => XADD => ('rpc_requests', '*', $request_data->@*), sub {
        my ($redis, $error, $message_id) = @_;
        use Data::Dumper;
        warn Dumper $error;
        warn Dumper $message_id;
        $f->done;
    });

    return $f;

}

sub prepare_request {
    my ($self, $c ,$req_storage) = @_;

    my $method = $req_storage->{method};

    $req_storage->{call_params} ||= {};

    my $params = $self->make_call_params($c, $req_storage);
    my $stash_params = $req_storage->{stash_params};

    return [
        rpc     => $method,
        args    => encode_json_utf8($params),
        stash   => encode_json_utf8($stash_params),
        who     => $self->whoami,
        timeout => time + RESPONSE_TIMEOUT,
    ];
}

1;
