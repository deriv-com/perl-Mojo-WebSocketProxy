use Test::More;
use Mojo::WebSocketProxy::Backend::ConsumerGroups;
use Test::MockObject;
use Test::Fatal;


subtest whoami => sub {
    my $rpc_backend1 = Mojo::WebSocketProxy::Backend::ConsumerGroups->new();
    my $rpc_backend2 = Mojo::WebSocketProxy::Backend::ConsumerGroups->new();

    my $rpc_id1 = $rpc_backend1->whoami;
    ok $rpc_id1, 'Got rpc id';

    is $rpc_id1, $rpc_backend1->whoami, 'Id will be unchanged for rpc instance';


    my $rpc_id2 = $rpc_backend2->whoami;
    ok $rpc_id2, 'Got rpc id';

    is $rpc_id1, $rpc_backend1->whoami, 'Id will be unchanged for rpc instance';
    is $rpc_id2, $rpc_backend2->whoami, 'Id will be unchanged for rpc instance';

    isnt $rpc_id1, $rpc_id2 , 'Id is uniq';
};

subtest send_reuqest => sub {

    my $redis = Test::MockObject->new();
    $redis->mock( _execute => sub { pop->(undef, 'test error') });

    my $cg_backend = Mojo::WebSocketProxy::Backend::ConsumerGroups->new(redis => $redis);
    my $err = exception { $cg_backend->send_request()->get };

    like $err, qr{^test error}, 'Got correct error';

    $redis->mock( _execute => sub { pop->(undef, undef, 'msg_id_123') });

    my $msg_id = eval { $cg_backend->send_request()->get };

    is $msg_id, 'msg_id_123', 'Got correct message id';
};



done_testing;
