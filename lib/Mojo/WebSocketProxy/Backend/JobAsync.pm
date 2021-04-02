package Mojo::WebSocketProxy::Backend::JobAsync;

use strict;
use warnings;

use parent qw(Mojo::WebSocketProxy::Backend);

no indirect;

use DataDog::DogStatsd::Helper qw(stats_inc);
use IO::Async::Loop::Mojo;
use Job::Async;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use Log::Any qw($log);
use MojoX::JSON::RPC::Client;
use Syntax::Keyword::Try;

## VERSION

__PACKAGE__->register_type('job_async');

=head1 NAME

Mojo::WebSocketProxy::Backend::JobAsync

=head1 DESCRIPTION

A subclass of L<Mojo::WebSocketProxy::Backend> which dispatches RPC requests
via L<Job::Async>.

=cut

=head1 CONSTANTS

=head2 QUEUE_TIMEOUT

A duration of timeout in seconds (default: 300) for receiving response from RPC queue.
The default value can be orverriden by setting an environment variable of the same name:

    $ENV{QUEUE_TIMEOUT} = 2;

=cut

use constant QUEUE_TIMEOUT => $ENV{QUEUE_TIMEOUT} // 300;

=head1 CLASS METHODS

=head2 new

Returns a new instance. Required params:

=over 4

=item loop => IO::Async::Loop

Containing L<IO::Async::Loop> instance.

=item jobman => Job::Async

Optional L<Job::Async> instance. If non-empty, it should be already added to the C<loop>.

=item client => Job::Async::Client

Optional L<Job::Async::Client> instance. If non-empty, it should be constructed by  C<< $jobman->client >>.
Will be constructed from C<< $jobman->client >> if not provided.

=back

=cut

sub new {
    my ($class, %args) = @_;

    my $self = bless \%args, $class;

    return $self;
}

=head1 METHODS

=cut

=head2 client

    $client = $backend->client

Returns the L<Job::Async::Client> instance.

=cut

sub client {
    my $self = shift;
    return $self->{client} //= do {
        # Let's not pull it in unless we have it already, but we do want to avoid sharing number
        # sequences in forked workers.
        Math::Random::Secure::srand() if Math::Random::Secure->can('srand');
        my $client_job = $self->jobman->client(redis => $self->{redis});
        $client_job->start;
        $client_job;
    };
}

=head2 loop

    $client = $backend->loop

Returns the async IO loop object.

=cut

sub loop {
    my $self = shift;
    return $self->{loop} //= do {
        require IO::Async::Loop::Mojo;
        local $ENV{IO_ASYNC_LOOP} = 'IO::Async::Loop::Mojo';
        IO::Async::Loop->new;
    };
}

=head2 jobman

    $jobman = $backend->jobman

Returns an object of L<Job::Async> that acts as job manager for the queue client.

=cut

sub jobman {
    my $self = shift;
    return $self->{jobman} //= do {
        $self->loop->add(my $jobman = Job::Async->new);
        $jobman;
    }
}

=head2 call_rpc

Implements the L<Mojo::WebSocketProxy::Backend/call_rpc> interface.

=cut

sub call_rpc {
    my ($self, $c, $req_storage) = @_;
    my $method   = $req_storage->{method};
    my $msg_type = $req_storage->{msg_type} ||= $req_storage->{method};

    $req_storage->{call_params} ||= {};
    my $rpc_response_cb = $self->get_rpc_response_cb($c, $req_storage);

    my $before_get_rpc_response_hooks = delete($req_storage->{before_get_rpc_response}) || [];
    my $after_got_rpc_response_hooks  = delete($req_storage->{after_got_rpc_response})  || [];
    my $before_call_hooks             = delete($req_storage->{before_call})             || [];
    my $rpc_failure_cb                = delete($req_storage->{rpc_failure_cb})          || 0;

    my $params = $self->make_call_params($c, $req_storage);
    $log->debugf("method %s has params = %s", $method, $params);

    foreach my $hook (@$before_call_hooks) { $hook->($c, $req_storage) }

    my $timeout_future = $self->loop->timeout_future(after => QUEUE_TIMEOUT);
    Future->wait_any(
        $self->client->submit(
            name   => $req_storage->{name},
            params => encode_json_utf8($params),
        ),
        $timeout_future
    )->on_ready(
        sub {
            my ($f) = @_;
            $log->debugf('->submit completion: ', $f->state);

            foreach my $hook (@$before_get_rpc_response_hooks) { $hook->($c, $req_storage) }

            # unconditionally stop any further processing if client is already disconnected

            return Future->done unless $c and $c->tx;

            my $api_response;
            my $result;
            if ($f->is_done) {
                try {
                    $result = MojoX::JSON::RPC::Client::ReturnObject->new(rpc_response => decode_json_utf8($f->get));

                    foreach my $hook (@$before_get_rpc_response_hooks) { $hook->($c, $req_storage, $result) }

                    $api_response = $rpc_response_cb->($result->result);
                    stats_inc("rpc_queue.client.jobs.success", {tags => ["rpc:" . $req_storage->{name}, 'clientID:' . $self->client->id]});
                } catch {
                    my $error = $@;
                    $log->errorf("Failed to process response of method %s: %s", $method, $error);
                    stats_inc("rpc_queue.client.jobs.fail",
                        {tags => ["rpc:" . $req_storage->{name}, 'clientID:' . $self->client->id, 'error:' . $error]});

                    $rpc_failure_cb->($c, $result, $req_storage) if $rpc_failure_cb;
                    $api_response = $c->wsp_error($msg_type, 'WrongResponse', 'Sorry, an error occurred while processing your request.');
                };
            } else {
                my $failure = $f->is_failed ? $f->failure // '' : 'RPC request was cancelled. Subscription is not ready.';

                $log->errorf("Method %s failed: %s", $method, $failure);
                stats_inc("rpc_queue.client.jobs.fail",
                    {tags => ["rpc:" . $req_storage->{name}, 'clientID:' . $self->client->id, 'error:' . $failure]});

                $rpc_failure_cb->($c, $result, $req_storage) if $rpc_failure_cb;
                if ($timeout_future->is_failed) {
                    $api_response = $c->wsp_error($msg_type, 'RequestTimeout', 'Request is timed out.');
                } else {
                    $api_response = $c->wsp_error($msg_type, 'WrongResponse', 'Sorry, an error occurred while processing your request.');
                }
            }

            return unless $api_response;

            $c->send({json => $api_response}, $req_storage);
        })->retain;
    return;
}

1;

