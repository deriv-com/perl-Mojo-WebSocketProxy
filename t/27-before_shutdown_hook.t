use strict;
use warnings;

use t::TestWSP qw/test_wsp/;
use Test::More;
use Test::Mojo;
use Mojo::IOLoop;
use Future;

subtest "before shutdown hook" => sub {
    my $hook_was_called = 0;

    package t::MyApp {
        use base 'Mojolicious';

        sub startup {
             my $self = shift;
             $self->plugin(
                 'web_socket_proxy' => {
                    actions => [
                        ['success'],
                    ],
                    base_path => '/api',
                    url => $ENV{T_TestWSP_RPC_URL} // die("T_TestWSP_RPC_URL is not defined"),
                    before_shutdown => sub { $hook_was_called++ },
                 }
             );
        }
    };


    my $t = Test::Mojo->new('t::MyApp');

    Mojo::IOLoop->singleton->emit('finish');

    is $hook_was_called, 1 'Hook is called exactly one time';
};

done_testing;

