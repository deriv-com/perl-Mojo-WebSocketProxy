use Object::Pad;

class Mojo::WebSocketProxy::RequestLogger;

use strict;
use warnings;
use Log::Any::Adapter 'DERIV',
    log_level => 'info',
    stderr    => 'json';
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
method log_message($level, $message, @params) {
    $log->adapter->set_context($req_storage->{logger_context});
    $log->$level($message, @params);
    $log->adapter->clear_context;
}

method infof($message, @params) {
    $self->log_message('info', $message, @params);
}

method tracef($message, @params) {
    $self->log_message('trace', $message, @params);
}

method errorf($message, @params) {
    $self->log_message('error', $message, @params);
}

method warnf($message, @params) {
    $self->log_message('warning', $message, @params);
}

method debugf($message, @params) {
    $self->log_message('debug', $message, @params);
}

1;
