use strict;
use warnings;

use t::TestWSP qw/test_wsp/;
use Test::More;
use Test::Mojo;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::IOLoop;
use Future;

package t::FrontEnd {
    use base 'Mojolicious';
    # does not matter
    sub startup {
         my $self = shift;
         $self->helper('l' => sub {
            my ($c, $message) = @_;
            return "[localized] : $message";
         });
         $self->plugin(
             'web_socket_proxy' => {
                localizer => sub { shift->l(shift) },
                actions => [
                    ['success', {stash_params => [qw/lang/]}],
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
    $t->send_ok({json => 'invalid', lang => 'ru'})->message_ok;
    is decode_json($t->message->[1])->{error}->{code}, 'BadRequest';
    is decode_json($t->message->[1])->{error}->{message}, '[localized] : The application sent an invalid request.';
} 't::FrontEnd';

done_testing;
