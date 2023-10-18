use Test::More;
use Mojo::WebSocketProxy::RequestLogger;

my $context = {'correlation_id' => '1234'};
my $logger = Mojo::WebSocketProxy::RequestLogger->new(context => $context);


subtest 'Test log_message method' => sub {
    $logger->log_message('debug', 'This is a debug message');
    $logger->log_message('info', 'This is an info message');
    $logger->log_message('warn', 'This is a warning message');
    $logger->log_message('error', 'This is an error message');
    pass('All log levels tested');
};

subtest 'Test get_context method' => sub {
    my $context = $logger->get_context();
    ok($context->{correlation_id}, 'Correlation ID exists');
};

done_testing();
