use Object::Pad;

class Mojo::WebSocketProxy::RequestLogger;

use strict;
use warnings;
use Log::Any qw($log);

field $req_storage: param;

# Method to set the context
method set_context($context) {
    $log->adapter->set_context($context);
}

# Method to clear the context
method clear_context {
    $log->adapter->clear_context;
}

# Method to log messages with various log levels
method log_message($level, $message) {
    $log->adapter->set_context($req_storage->{correlation_id});
    $log->$level($message);
    $log->adapter->clear_context;
}

method infof ($message) {
    $self->log_message('info', $message);
}

method tracef ($message) {
    $self->log_message('trace', $message);
}

method errorf ($message) {
    $self->log_message('error', $message);
}

method warnf ($message) {
    $self->log_message('warning', $message);
}

method debugf ($message) {
    $self->log_message('debug', $message);
}

1;
