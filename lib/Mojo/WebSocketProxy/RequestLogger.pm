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

method infof($message, @params) {
    $self->log_message('infof', $message, @params);
}

method tracef($message, @params) {
    $self->log_message('tracef', $message, @params);
}

method errorf($message, @params) {
    $self->log_message('errorf', $message, @params);
}

method warnf($message, @params) {
    $self->log_message('warningf', $message, @params);
}

method debugf($message, @params) {
    $self->log_message('debugf', $message, @params);
}

method info($message) {
    $self->log_message('info', $message);
}

method trace($message) {
    $self->log_message('trace', $message);
}

method error($message) {
    $self->log_message('error', $message);
}

method warn($message) {
    $self->log_message('warning', $message);
}

method debug($message) {
    $self->log_message('debug', $message);
}

method get_context(){
    return $context;
}

1;
