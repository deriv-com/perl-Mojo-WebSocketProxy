package Mojo::WebSocketProxy::Backend::JobAsync;

use strict;
use warnings;

use parent qw(Mojo::WebSocketProxy::Backend);

no indirect;

use IO::Async::Loop::Mojo;
use Job::Async;

use Log::Any qw($log);

## VERSION

__PACKAGE__->register_type( 'job_async' );

sub new {
    my ($class, %args) = @_;
    # Avoid holding these - we only want the Job::Async::Client instance, and everything else
    # should be attached to the loop (which sticks around longer than we expect to).
    my $loop = delete $args{loop};
    my $jobman = delete $args{jobman};

    my $self = bless \%args, $class;

    # We'd like to provide some flexibility for people trying to integrate this into
    # other systems, so any combination of Job::Async::Client, Job::Async and/or IO::Async::Loop
    # instance can be provided here.
    $self->{client} //= do {
        unless($jobman) {
            # We don't hold a ref to this, since that might introduce unfortunate cycles
            $loop //= do {
                require IO::Async::Loop::Mojo;
                IO::Async::Loop::Mojo->new;
            };
            $loop->add(
                $jobman = Job::Async->new
            );
        }

        $jobman->client;
    };
    return $self;
}

sub client { shift->{client} }

sub call_rpc {
    my ($self, $c, $req_storage) = @_;
    my $method   = $req_storage->{method};
    my $msg_type = $req_storage->{msg_type} ||= $req_storage->{method};

    $req_storage->{call_params} ||= {};

    my $rpc_response_cb = $self->get_rpc_response_cb($c, $req_storage);

    my $before_get_rpc_response_hook = delete($req_storage->{before_get_rpc_response}) || [];
    my $after_got_rpc_response_hook  = delete($req_storage->{after_got_rpc_response})  || [];
    my $before_call_hook             = delete($req_storage->{before_call})             || [];
    my $params = $self->make_call_params($c, $req_storage);
    $log->debugf("method %s has params = %s", $method, $params);

    $_->($c, $req_storage) for @$before_call_hook;

    $self->client->submit(
        data => $req_storage
    )->on_ready(sub {
        my ($f) = @_;
        $log->debugf('->submit completion: ', $f->state);

        $_->($c, $req_storage) for @$before_get_rpc_response_hook;

        # unconditionally stop any further processing if client is already disconnected
        return Future->done unless $c and $c->tx;

        my $api_response;
        if($f->is_done) {
            my ($result) = $f->get;

            $_->($c, $req_storage, $result) for @$after_got_rpc_response_hook;

            $api_response = $rpc_response_cb->($result);
        }
        else {
            my ($failure) = $f->failure;
            $log->warnf("method %s failed: %s", $method, $failure);

            $api_response = $c->wsp_error(
                $msg_type, 'CallError', 'Sorry, an error occurred while processing your request.'
            );
        }
        return unless $api_response;

        $c->send({json => $api_response}, $req_storage);
    })->retain;
    return;
}

1;

