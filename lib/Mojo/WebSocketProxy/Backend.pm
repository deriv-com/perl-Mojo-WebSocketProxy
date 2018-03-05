package Mojo::WebSocketProxy::Backend;

use strict;
use warnings;

no indirect;

use Mojo::Util qw(class_to_path);

## VERSION

our %CLASSES = (
    jsonrpc   => 'Mojo::WebSocketProxy::Backend::JSONRPC',
    job_async => 'Mojo::WebSocketProxy::Backend::JobAsync',
);

sub class_for_type {
    my ($class, $type) = @_;
    my $target_class = $CLASSES{$type};
    # extra () around require to avoid treating the function call as a class name
    require(class_to_path($target_class)) unless $target_class->can('new');
    return $target_class;
}

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class unless $class eq __PACKAGE__;

    my $type = delete $args{type} or die 'need a backend type';
    my $backend_class = $class->class_for_type($type) or die 'unknown backend type ' . $type;
    return $backend_class->new(%args);
}

=head2 METHODS - For backend classes

These will be inherited by backend implementations and can be used
for some common actions when processing requests and responses.

=cut

sub make_call_params {
    my ($self, $c, $req_storage) = @_;

    my $args         = $req_storage->{args};
    my $stash_params = $req_storage->{stash_params};

    my $call_params = $req_storage->{call_params};
    $call_params->{args} = $args;

    if (defined $stash_params) {
        $call_params->{$_} = $c->stash($_) for @$stash_params;
    }

    return $call_params;
}

sub get_rpc_response_cb {
    my ($self, $c, $req_storage) = @_;

    my $success_handler = delete $req_storage->{success};
    my $error_handler   = delete $req_storage->{error};

    if (my $rpc_response_cb = delete $req_storage->{rpc_response_cb}) {
        return sub {
            my $rpc_response = shift;
            return $rpc_response_cb->($c, $rpc_response, $req_storage);
        };
    } else {
        return sub {
            my $rpc_response = shift;
            if (ref($rpc_response) eq 'HASH' and exists $rpc_response->{error}) {
                $error_handler->($c, $rpc_response, $req_storage) if defined $error_handler;
                return error_api_response($c, $rpc_response, $req_storage);
            } else {
                $success_handler->($c, $rpc_response, $req_storage) if defined $success_handler;
                store_response($c, $rpc_response);
                return success_api_response($c, $rpc_response, $req_storage);
            }
            return;
        };
    }
    return;
}

sub store_response {
    my ($c, $rpc_response) = @_;

    if (ref($rpc_response) eq 'HASH' && $rpc_response->{stash}) {
        $c->stash(%{delete $rpc_response->{stash}});
    }
    return;
}

sub success_api_response {
    my ($c, $rpc_response, $req_storage) = @_;

    my $msg_type             = $req_storage->{msg_type};
    my $rpc_response_handler = $req_storage->{response};

    my $api_response = {
        msg_type  => $msg_type,
        $msg_type => $rpc_response,
    };

    if (ref($rpc_response) eq 'HASH' and keys %$rpc_response == 1 and exists $rpc_response->{status}) {
        $api_response->{$msg_type} = $rpc_response->{status};
    }

    if ($rpc_response_handler) {
        return $rpc_response_handler->($rpc_response, $api_response, $req_storage);
    }

    return $api_response;
}

sub error_api_response {
    my ($c, $rpc_response, $req_storage) = @_;

    my $msg_type             = $req_storage->{msg_type};
    my $rpc_response_handler = $req_storage->{response};
    my $api_response =
        $c->wsp_error($msg_type, $rpc_response->{error}->{code}, $rpc_response->{error}->{message_to_client}, $rpc_response->{error}->{details});

    if ($rpc_response_handler) {
        return $rpc_response_handler->($rpc_response, $api_response, $req_storage);
    }

    return $api_response;
}

1;

__END__

=head1 NAME

Mojo::WebSocketProxy::Backend

=head1 DESCRIPTION

See L<Mojo::WebSocketProxy::Backend> for the original JSON::RPC backend.

=cut
