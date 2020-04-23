package Mojo::WebSocketProxy::Backend::ConsumerGroups::Request;

use strict;
use warnings;

use IO::Async::Loop::Mojo;
use Data::UUID;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use Syntax::Keyword::Try;

use parent qw(Mojo::WebSocketProxy::Backend);

no indirect;


sub new {
    my ($cls, %args) = @_;

    return bless \%args, $cls;
}



# TODO: Need to be renamed
sub c { shift->{c} }

sub storage { shift->{storage}}

sub args { shift->{args} }

sub timeout { shift->{timeout} }

# TODO: Yep that specification but better to rename it
sub who { shift->{who} }

sub msg_type {
    my $self 
}

sub before_call {
    my ($self) = @_;
    _call_hooks($self->storage->{before_call}, $self->c, $self->storage);
    return;
}

sub before_get_rpc_response {
    my ($self) = @_;
    _call_hooks($self->storage->{before_get_rpc_response}, $self->c, $self->storage);
    return;
}

sub after_got_rpc_response {
    my ($self, $result) = @_;
    _call_hooks($self->storage->{after_got_rpc_response}, $self->c, $self->storage, $result);
    return;
}

sub rpc_failure_cb {
    my ($self) = @_;
    _call_hooks(shift->storage->{rpc_failure_cb});
    return;
}

sub _call_hooks {
    my ($hooks) = shift;

    return unless $hooks;

    return $hooks->(@_) if ref $hooks eq 'CODE';

    return unless ref $hooks eq 'ARRAY';

    $_->(@_) for $hooks->@*;

    return;
}

sub serialize {
    my ($self) = @_;

    return [
        rpc     => $self->storage->{method},
        args    => encode_json_utf8($self->args),
        stash   => encode_json_utf8($self->storage->{stash_params}),
        who     => $self->who,
        timeout => $self->timeout,
    ];
}




1;
