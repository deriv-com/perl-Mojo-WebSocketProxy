use Test::More;
use Mojo::WebSocketProxy::Backend::ConsumerGroups;


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
    my $c = Mojo::WebSocketProxy::Backend::ConsumerGroups->new(redis_uri => 'redis://127.0.0.1:6359');

    $c->send_request([test => 123])->get;
    ok 1;
};



done_testing;
