package Mojo::WebSocketProxy::Backend::ConsumerGroups;

use strict;
use warnings;

use Math::Random::Secure;
use Mojo::Redis2;
use IO::Async::Loop::Mojo;
use Data::UUID;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use Syntax::Keyword::Try;
use curry::weak;
use MojoX::JSON::RPC::Client;

use parent qw(Mojo::WebSocketProxy::Backend);

no indirect;

## VERSION

__PACKAGE__->register_type('consumer_groups');


use constant RESPONSE_TIMEOUT => $ENV{RPC_QUEUE_RESPONSE_TIMEOUT} // 300;

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

sub timeout {
    return shift->{timeout} //= RESPONSE_TIMEOUT;
}

sub whoami {
    my $self = shift;

    return $self->{whoami} if $self->{whoami};

    Math::Random::Secure::srand() if Math::Random::Secure->can('srand');
    $self->{whoami} = Data::UUID->new->create_str();

    return $self->{whoami};
}


sub call_rpc {
    my ($self, $c, $req_storage) = @_;

    # make sure that we are already waiting for messages
    # calling this sub multiple time is safe, it will be executed once

    my ($msg_type, $request_data) = $self->_prepare_request_data($c, $req_storage);

    my $rpc_response_cb = $self->get_rpc_response_cb($c, $req_storage);
    my $before_get_rpc_response_hooks = delete($req_storage->{before_get_rpc_response}) || [];
    my $after_got_rpc_response_hooks  = delete($req_storage->{after_got_rpc_response})  || [];
    my $before_call_hooks             = delete($req_storage->{before_call})             || [];
    my $rpc_failure_cb                = delete($req_storage->{rpc_failure_cb});


    foreach my $hook ($before_call_hooks->@*) { $hook->($c, $req_storage) }

    $self->request($request_data)->then(sub {
        my ($message) = @_;

        foreach my $hook ($before_get_rpc_response_hooks->@*) { $hook->($c, $req_storage) }

        return Future->done unless $c && $c->tx;
        my $api_response;
        my $result;

        try {
            $result = MojoX::JSON::RPC::Client::ReturnObject->new(rpc_response => $message);
            foreach my $hook ($after_got_rpc_response_hooks->@*) { $hook->($c, $req_storage, $result) }
            $api_response = $rpc_response_cb->($result->result);
        } catch {
            my $error = $@;
            $rpc_failure_cb->($c, $result, $req_storage) if $rpc_failure_cb;
            $api_response = $c->wsp_error($msg_type, 'WrongResponse', 'Sorry, an error occurred while processing your request.');
        };

        $c->send({json => $api_response}, $req_storage);

        return Future->done;
    })->catch(sub {
        my $error = shift;
        my $api_response;

        if ($error eq 'Timeout') {
            $api_response = $c->wsp_error($msg_type, 'RequestTimeout', 'Request is timed out.');
        } else {
            $api_response = $c->wsp_error($msg_type, 'WrongResponse', 'Sorry, an error occurred while processing your request.');
        }
        $rpc_failure_cb->($c, undef, $req_storage) if $rpc_failure_cb;

        $c->send({json => $api_response}, $req_storage);
    })->retain;


    return;
}


sub request {
    my ($self, $request_data) = @_;

    my $complete_future = $self->loop->new_future;

    $self->wait_for_messages();

    my $sent_future = $self->_send_request($request_data)->then(sub {
        my ($msg_id) = @_;

        $self->pending_requests->{$msg_id} = $complete_future;

        $complete_future->on_cancel(sub { delete $self->pending_requests->{$msg_id} });

        return Future->done;
    });


    return Future->wait_any(
        $self->loop->timeout_future(after => $self->timeout),
        Future->needs_all($complete_future, $sent_future),
    );
}


sub _send_request {
    my ($self, $request_data) = @_;

    my $f = $self->loop->new_future;
    $self->redis->_execute(xadd => XADD => ('rpc_requests', '*', $request_data->@*), sub {
        my ($redis, $err, $msg_id) = @_;

        return $f->fail($err) if $err;

        return $f->done($msg_id);
    });

    return $f;
}

sub wait_for_messages {
    my ($self) = @_;
    $self->{already_waiting} //= $self->redis->subscribe(
        [$self->whoami],
        $self->$curry::weak(sub {
            my ($self) = @_;
            $self->redis->on('message', $self->$curry::weak('_on_message'));
        })
    );

    return;
}

sub _on_message {
    my ($self, $redis, $raw_message) = @_;

    my $message = eval{ decode_json_utf8($raw_message) };

    return unless ref $message eq 'HASH' && $message->{original_id};

    my $completion_future = delete $self->pending_requests->{$message->{original_id}};

    return unless $completion_future;

    $completion_future->done($message);

    return;
}

sub _prepare_request_data {
    my ($self, $c, $req_storage) = @_;

    $req_storage->{call_params} ||= {};

    my $method = $req_storage->{method};
    my $msg_type = $req_storage->{msg_type} ||= $req_storage->{method};

    my $params = $self->make_call_params($c, $req_storage);
    my $stash_params = $req_storage->{stash_params};

    return $msg_type, [
        rpc     => $method,
        args    => encode_json_utf8($params),
        stash   => encode_json_utf8($stash_params),
        who     => $self->whoami,
        timeout => time + RESPONSE_TIMEOUT,
    ];
}

1;
