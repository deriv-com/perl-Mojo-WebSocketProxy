package Mojo::WebSocketProxy::Backend::JSONRPC;

use strict;
use warnings;

use parent qw(Mojo::WebSocketProxy::Backend);

use feature qw(state);

no indirect;

use curry;

use MojoX::JSON::RPC::Client;

## VERSION

sub url { shift->{url} }

my $request_number = 0;

sub call_rpc {
    my ($self, $c, $req_storage) = @_;
    state $client  = MojoX::JSON::RPC::Client->new;

    my $url = $req_storage->{url} // $self->url;
    die 'No url found' unless $url;

    $url .= $req_storage->{method};

    my $method   = $req_storage->{method};
    my $msg_type = $req_storage->{msg_type} ||= $req_storage->{method};

    $req_storage->{call_params} ||= {};

    my $rpc_response_cb = $self->get_rpc_response_cb($c, $req_storage);

    my $before_get_rpc_response_hook = delete($req_storage->{before_get_rpc_response}) || [];
    my $after_got_rpc_response_hook  = delete($req_storage->{after_got_rpc_response})  || [];
    my $before_call_hook             = delete($req_storage->{before_call})             || [];

    my $callobj = {
        # enough for short-term uniqueness
        id     => join('_', $$, $request_number++, time, (0+[])),
        method => $method,
        params => $self->make_call_params($c, $req_storage),
    };

    $_->($c, $req_storage) for @$before_call_hook;

    $client->call(
        $url, $callobj,
        $client->$curry::weak(sub {
            my $client = shift;
            my $res = pop;

            $_->($c, $req_storage) for @$before_get_rpc_response_hook;

            # unconditionally stop any further processing if client is already disconnected
            return unless $c->tx;

            my $api_response;
            if (!$res) {
                my $tx = $client->tx;
                my $details = 'URL: ' . $tx->req->url;
                if (my $err = $tx->error) {
                    $details .= ', code: ' . ($err->{code} // 'n/a') . ', response: ' . $err->{message};
                }
                warn "WrongResponse [$msg_type], details: $details";
                $api_response = $c->wsp_error($msg_type, 'WrongResponse', 'Sorry, an error occurred while processing your request.');
                $c->send({json => $api_response}, $req_storage);
                return;
            }

            $_->($c, $req_storage, $res) for @$after_got_rpc_response_hook;

            if ($res->is_error) {
                warn $res->error_message;
                $api_response = $c->wsp_error($msg_type, 'CallError', 'Sorry, an error occurred while processing your request.');
                $c->send({json => $api_response}, $req_storage);
                return;
            }

            $api_response = $rpc_response_cb->($res->result);

            return unless $api_response;

            $c->send({json => $api_response}, $req_storage);

            return;
        });
    return;
}

1;

__END__

=head1 NAME

Mojo::WebSocketProxy::Backend

=head1 DESCRIPTION

The calling engine which does the actual RPC call.

=head1 METHODS

=head2 forward

Forward the call to RPC service and return response to websocket connection.

Call params is made in make_call_params method.
Response is made in success_api_response method.
These methods would be override or extend custom functionality.

=head2 make_call_params

Make RPC call params.

Method params:
    stash_params - it contains params to forward from server storage.

=head2 rpc_response_cb

Callback for RPC service response.
Can use custom handlers error and success.

=head2 store_response

Save RPC response to storage.

=head2 success_api_response

Make wsapi proxy server response from RPC response.

=head2 error_api_response

Make wsapi proxy server response from RPC response.

=head2 call_rpc

Make RPC call.

=head2 get_rpc_response_cb

=head1 SEE ALSO

L<Mojolicious::Plugin::WebSocketProxy>,
L<Mojo::WebSocketProxy>
L<Mojo::WebSocketProxy::Dispatcher>,
L<Mojo::WebSocketProxy::Config>
L<Mojo::WebSocketProxy::Parser>

=cut
