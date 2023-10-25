use Object::Pad;

class Mojo::WebSocketProxy::RequestLogger;

use strict;
use warnings;
use Log::Any qw($log);
use UUID::Tiny;

field $context;

our $default_handler = sub {
    my ($level, $message, $context, @params) = @_;

    if(scalar @params) {
        return $log->$level($message, @params);
    }

    return $log->$level($message, $context);
};

sub set_handler {
    my ($self, $custom_handler) = @_;
    $default_handler = $custom_handler;
} 

BUILD{
    $context->{correlation_id} =  UUID::Tiny::create_UUID_as_string(UUID::Tiny::UUID_V4);
}

method infof($message, @params) {
    $default_handler->('infof', $message, $context, @params);
}

method tracef($message, @params) {
    $default_handler->('tracef', $message, $context, @params);
}

method errorf($message, @params) {
    $default_handler->('errorf', $message, $context, @params);
}

method warnf($message, @params) {
    $default_handler->('warningf', $message, $context, @params);
}

method debugf($message, @params) {
    $default_handler->('debugf', $message, $context, @params);
}

method critf($message, @params) {
    $default_handler->('critf', $message, $context, @params);
}

method info($message) {
    use Data::Dumper;
    print 'here to print message';
    $default_handler->('info', $message, $context);
}

method trace($message) {
    $default_handler->('trace', $message , $context);
}

method error($message) {
    $default_handler->('error', $message, $context);
}

method warn($message) {
    $default_handler->('warning', $message, $context);
}

method debug($message) {
    $default_handler->('debug', $message, $context);
}

method crit($message) {
    $default_handler->('crit', $message, $context);
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
