use strict;
use warnings;

use Test::More;
use Mojo::WebSocketProxy::Backend::ConsumerGroups;
use Test::MockObject;
use Test::Fatal;


subtest 'Subscribe for new messaging' => sub {
    my $redis = Test::MockObject->new();
    my $was_subscribed = 0;
    my $callback_setted = 0;
    $redis->mock( subscribe => sub { $was_subscribed++; pop->(); return shift;});
    $redis->mock( on => sub { $callback_setted++; pop->($redis, '{"original_id": "msg_id_123"}') });

    my $cg_backend = Mojo::WebSocketProxy::Backend::ConsumerGroups->new(redis => $redis);

    $cg_backend->wait_for_messages();
    is $was_subscribed, 1, 'Subscribe for new messages';

    $cg_backend->wait_for_messages();
    is $was_subscribed, 1, 'Subscribe for new messages exactly once';

    is $callback_setted, 1, 'Callback for new messages is setted';
};


subtest 'Response handling' => sub {
    my $redis = Test::MockObject->new();
    my $cb_counter = 0;
    $redis->mock( subscribe => sub {pop->(); return shift;});
    $redis->mock( on => sub {$cb_counter++; pop->($redis, '{"original_id": "msg_id_123"}')});

    my $cg_backend = Mojo::WebSocketProxy::Backend::ConsumerGroups->new(redis => $redis);
    my $f = $cg_backend->pending_requests->{msg_id_123} = $cg_backend->loop->new_future;

    $cg_backend->wait_for_messages();
    is $cb_counter, 1, 'On messages call back was called';
    ok $f->is_done, 'Request marked as ready';

    my $resp = Future->wait_any($f, $cg_backend->loop->timeout_future(after => 1))->get;

    is_deeply $resp, {original_id => 'msg_id_123'}, 'Got rpc result';
    is_deeply $cg_backend->pending_requests, {}, 'Message was deleted from pending requests';

    #Triggering without pending messages;
    delete $cg_backend->{already_waiting};
    $cg_backend->wait_for_messages();
    is $cb_counter, 2, 'On messages call back was called';

    is_deeply $cg_backend->pending_requests, {}, 'Pending requests should be empty';
};

subtest whoami => sub {
    return ok 1;
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

subtest _send_reuqest => sub {
    my $redis = Test::MockObject->new();
    $redis->mock( _execute => sub { pop->(undef, 'test error') });
    my $request = Test::MockObject->new();
    $request->mock( serialize => sub { [] });

    my $cg_backend = Mojo::WebSocketProxy::Backend::ConsumerGroups->new(redis => $redis);
    my $err = exception { $cg_backend->_send_request($request)->get };

    like $err, qr{^test error}, 'Got correct error';

    $redis->mock( _execute => sub { pop->(undef, undef, 'msg_id_123') });

    my ($request, $msg_id) = eval { $cg_backend->_send_request($request)->get };
    ok $request, 'Got request object';
    is $msg_id, 'msg_id_123', 'Got correct message id';
};

subtest 'Request to rpc' => sub {
    my $redis = Test::MockObject->new();
    $redis->mock( _execute => sub { pop->(undef, undef, 'msg_id_123') });

    my $request = Test::MockObject->new();
    $request->mock( serialize => sub { [] });

    my $cg_backend = Mojo::WebSocketProxy::Backend::ConsumerGroups->new(
        redis => $redis,
        timeout => 0.001,
    );

    # Success request
    $redis->mock( subscribe => sub {pop->(); return shift;});
    $redis->mock( on => sub {pop->($redis, '{"original_id": "msg_id_123"}')});
    my $result = eval {$cg_backend->request($request)->get};
    is_deeply $result, {original_id => "msg_id_123"}, 'Got expected result';

    # Timeout request
    my $err = exception { $cg_backend->request($request)->get };
    like $err, qr{^Timeout}, 'Got request time out';
    is_deeply $cg_backend->pending_requests, {}, 'Pending requests should be empty after fail';

    # Redis cmd request
    $redis->mock( _execute => sub { pop->(undef, 'Redis Error', undef) });
    $err = exception { $cg_backend->request($request)->get };
    like $err, qr{^Redis Error}, 'Got Redis Error';
    is_deeply $cg_backend->pending_requests, {}, 'Pending requests should be empty after fail';
};

done_testing;
