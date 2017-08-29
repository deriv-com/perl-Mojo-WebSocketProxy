use strict;
use warnings;

use t::TestWSP qw/test_wsp/;
use Test::More;
use Test::Mojo;
use JSON::XS;
use Mojo::IOLoop;
use Future;


package t::FrontEnd {
    use base 'Mojolicious';

    sub startup {
         my $self = shift;
         $self->plugin(
             'web_socket_proxy' => {
                actions => [],
                binary_frame => sub {
                    my ($c, $bytes) = @_;
                    my $payload = unpack 'a*', $bytes;
                    $c->send({json => {payload => $payload}});
                },
                base_path => '/api',
                url => $ENV{T_TestWSP_RPC_URL} // die("T_TestWSP_RPC_URL is not defined"),
             }
         );
    }
};

test_wsp {
    my ($t) = @_;
    my $expected_payload = 'Hello world!';
    $t->websocket_ok('/api' => {});
    $t->send_ok({binary => $expected_payload})->message_ok;
    is decode_json($t->message->[1])->{payload}, $expected_payload;
} 't::FrontEnd';

done_testing;
