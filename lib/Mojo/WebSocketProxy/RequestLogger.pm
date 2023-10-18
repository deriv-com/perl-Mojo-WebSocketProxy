use Object::Pad;

class Mojo::WebSocketProxy::RequestLogger;

use strict;
use warnings;
use Log::Any qw($log);
use UUID::Tiny;

field $context;
BUILD{
    $context->{correlation_id} =  UUID::Tiny::create_UUID_as_string(UUID::Tiny::UUID_V4);
}

# Method to log messages with various log levels
method log_message($level, $message, @params) {
    if($log->adapter->can('set_context')) {
        $log->adapter->set_context($context);
    }
    $log->$level($message, @params);
    if($log->adapter->can('clear_context')) {
        $log->adapter->clear_context;
    }
}

method get_context(){
    return $context;
}

1;
