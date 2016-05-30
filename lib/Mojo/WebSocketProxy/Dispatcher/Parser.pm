package Mojo::WebSocketProxy::Dispatcher::Parser;

use strict;
use warnings;

sub parse_req {
    my ($c, $req_storage) = @_;

    my $result;
    my $args = $req_storage->{args};
    if (ref $args ne 'HASH') {
        # for invalid call, eg: not json
        $req_storage->{args} = {};
        $result = $c->new_error('error', 'BadRequest', $c->l('The application sent an invalid request.'));
    }

    $result = _check_sanity($c, $req_storage) unless $result;

    return $result;
}

sub _check_sanity {
    my ($c, $req_storage) = @_;

    my @failed;
    my $args = $req_storage->{args};

    OUTER:
    foreach my $k (keys %$args) {
        if (not ref $args->{$k}) {
            last OUTER if (@failed = _failed_key_value($k, $args->{$k}));
        } else {
            if (ref $args->{$k} eq 'HASH') {
                foreach my $l (keys %{$args->{$k}}) {
                    last OUTER
                        if (@failed = _failed_key_value($l, $args->{$k}->{$l}));
                }
            } elsif (ref $args->{$k} eq 'ARRAY') {
                foreach my $l (@{$args->{$k}}) {
                    last OUTER if (@failed = _failed_key_value($k, $l));
                }
            }
        }
    }

    if (@failed) {
        $c->app->log->warn("Sanity check failed: " . $failed[0] . " -> " . ($failed[1] // "undefined"));
        my $result = $c->new_error('sanity_check', 'SanityCheckFailed', $c->l("Parameters sanity check failed."));
        if (    $result->{error}
            and $result->{error}->{code} eq 'SanityCheckFailed')
        {
            $req_storage->{args} = {};
        }
        return $result;
    }
    return;
}

sub _failed_key_value {
    my ($key, $value) = @_;

    if ($key =~ /password/) {    # TODO review carefully
        return;
    } elsif (
        $key !~ /^[A-Za-z0-9_-]{1,50}$/
        # !-~ to allow a range of acceptable characters. To find what is the range, look at ascii table

        # please don't remove: \p{Script=Common}\p{L}
        # \p{L} is to match utf-8 characters
        # \p{Script=Common} is to match double byte characters in Japanese keyboards, eg: '１−１−１'
        # refer: http://perldoc.perl.org/perlunicode.html
        # null-values are allowed
        or ($value and $value !~ /^[\p{Script=Common}\p{L}\s\w\@_:!-~]{0,300}$/))
    {
        return ($key, $value);
    }
    return;
}

1;
