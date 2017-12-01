use strict;
use warnings;

use t::TestWSP qw/test_wsp/;
use Test::More;
use Test::Mojo;
use Encode;
use JSON::MaybeXS;
use Mojo::IOLoop;
use Future;

package t::FrontEnd {
    use base 'Mojolicious';

    sub startup {
         my $self = shift;
         $self->plugin(
             'web_socket_proxy' => {
                actions => [
                    ['success', { rpc_response_cb => sub { return { "rpc_response_cb" => 'ok' } } }],
                ],
                base_path => '/api',
                url => $ENV{T_TestWSP_RPC_URL} // die("T_TestWSP_RPC_URL is not defined"),
             }
         );
    }
};

test_wsp {
    my ($t) = @_;
    $t->websocket_ok('/api' => {});
    $t->send_ok({json => {success => 1}})->message_ok;
    is JSON::MaybeXS->new->decode(Encode::decode_utf8($t->message->[1]))->{rpc_response_cb}, 'ok';
} 't::FrontEnd';

done_testing;
