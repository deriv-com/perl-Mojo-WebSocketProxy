package Mojo::WebSocketProxy::Dispatcher::Config;

use Mojo::Base -base;

my $actions;
my $config;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->{actions} = {%$actions} if $actions;
    $self->{config}  = {%$config}  if $config;
    return $self;
}

sub init {
    my ($self, $in_config) = @_;

    $config  = {};
    $actions = {};
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
L<Mojo::WebSocketProxy::Dispatcher::CallingEngine>,
L<Mojo::WebSocketProxy::Dispatcher::Config>
L<Mojo::WebSocketProxy::Dispatcher::Parser>

=cut
