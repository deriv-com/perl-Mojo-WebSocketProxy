use strict;
use warnings;
use Test::More;
use Test::MemoryGrowth;
use Mojo::WebSocketProxy::RequestLogger;

# Test the log message levels
sub test_log_levels {
    my ($logger, $log_level) = @_;

    my $log_message      = "Test $log_level message";
    my $expected_message = "Test $log_level message";

    my $memory_usage_before = memory_growth {
        $logger->$log_level($log_message);
    };

    is($logger->log_message('test', $log_message), $expected_message, "Testing $log_level level log");
    no_growth {
        $logger->$log_level($log_message);
    }
    'No Growth in memory for messages';
    is($logger->log_message('test', $log_message), $expected_message, "Testing $log_level level log with no growth");
}

# Test Mojo::WebSocketProxy::RequestLogger
my $req_storage = {param => {logger_context => 'context_data'}};
my $logger      = Mojo::WebSocketProxy::RequestLogger->new(req_storage => $req_storage);

# Test context is set properly
is($logger->{req_storage}{param}{logger_context}, 'context_data', "Testing if context is set properly");

# Test all log levels
test_log_levels($logger, 'info');
test_log_levels($logger, 'trace');
test_log_levels($logger, 'error');
test_log_levels($logger, 'warn');
test_log_levels($logger, 'debug');

done_testing();
