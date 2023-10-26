use Object::Pad;

class Mojo::WebSocketProxy::RequestLogger;

use strict;
use warnings;
use Log::Any qw($log);
use UUID::Tiny;

field $context;

our $log_handler = sub {
    my ($level, $message, $context, @params) = @_;

    if(scalar @params) {
        return $log->$level($message, @params);
    }

    return $log->$level($message, $context);
};

sub set_handler {
    my ($self, $custom_handler) = @_;
    $log_handler = $custom_handler;
} 

BUILD{
    $context->{correlation_id} =  UUID::Tiny::create_UUID_as_string(UUID::Tiny::UUID_V4);
}

method infof($message, @params) {
    $log_handler->('infof', $message, $context, @params);
}

method tracef($message, @params) {
    $log_handler->('tracef', $message, $context, @params);
}

method errorf($message, @params) {
    $log_handler->('errorf', $message, $context, @params);
}

method warnf($message, @params) {
    $log_handler->('warningf', $message, $context, @params);
}

method debugf($message, @params) {
    $log_handler->('debugf', $message, $context, @params);
}

method critf($message, @params) {
    $log_handler->('critf', $message, $context, @params);
}

method info($message) {
    $log_handler->('info', $message, $context);
}

method trace($message) {
    $log_handler->('trace', $message , $context);
}

method error($message) {
    $log_handler->('error', $message, $context);
}

method warn($message) {
    $log_handler->('warning', $message, $context);
}

method debug($message) {
    $log_handler->('debug', $message, $context);
}

method crit($message) {
    $log_handler->('crit', $message, $context);
}

method get_context(){
    return $context;
}

method add_context_key($key, $value) {
    $context->{$key} = $value;
}

method remove_context_key($key){
    delete $context->{$key};
}

1;
