package Mojo::WebSocketProxy::Config;

use strict;
use warnings;

use feature 'state';

sub config {
    my ($class, $in_config) = @_;
    return state $config ||= $in_config;
}

sub init {
    my ($self, $in_config) = @_;

    my $config  = {};
    $actions = {};
    
    die 'Wrong parameter' if $in_config->{opened_connection} && ref($in_config->{opened_connection}) ne 'CODE';
    die 'Wrong parameter' if $in_config->{finish_connection} && ref($in_config->{finish_connection}) ne 'CODE';
    
    %$config = %$in_config;
    return;
}

sub add_action {
    my ($self, $action, $order) = @_;
    my $name    = $action->[0];
    my $options = $action->[1];

    $actions->{$name} ||= $options;
    $actions->{$name}->{order} = $order;
    $actions->{$name}->{name}  = $name;

    return;
}

1;

__END__

=head1 NAME

Mojo::WebSocketProxy::Dispatcher::Parser

=head1 DESCRIPTION

This module using for store server configuration in memory.

=head1 SEE ALSO
 
L<Mojolicious::Plugin::WebSocketProxy>, 
L<Mojo::WebSocketProxy>,
L<Mojo::WebSocketProxy::CallingEngine>,
L<Mojo::WebSocketProxy::Dispatcher>,
L<Mojo::WebSocketProxy::Config>
L<Mojo::WebSocketProxy::Dispatcher::Parser>

=cut
