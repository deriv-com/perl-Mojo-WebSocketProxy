package Mojo::WebSocketProxy::Backend;

use strict;
use warnings;

no indirect;

use Mojo::Base -base;

use Mojo::WebSocketProxy::Backend::JSONRPC;

## VERSION

has 'url';

our %CLASSES = (
    jsonrpc   => 'Mojo::WebSocketProxy::Backend::JSONRPC',
    job_async => 'Mojo::WebSocketProxy::Backend::JobAsync',
);

sub class_for_type {
    my ($class, $type) = @_;
    return $CLASSES{$type};
}

sub new {
    my ($class, %args) = @_;
    my $type = delete $args{type} or die 'need a backend type';
    my $backend_class = $class->class_for_type($type) or die 'unknown backend type ' . $type;
    return $backend_class->new(%args);
}

1;

__END__

=head1 NAME

Mojo::WebSocketProxy::Backend

=head1 DESCRIPTION

See L<Mojo::WebSocketProxy::Backend> for the original JSON::RPC backend.

=cut
