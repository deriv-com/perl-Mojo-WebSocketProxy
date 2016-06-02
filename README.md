# perl-Mojo-WebSocketProxy
[![Build Status](https://travis-ci.org/binary-com/perl-Mojo-WebSocketProxy.svg?branch=master)](https://travis-ci.org/binary-com/perl-Mojo-WebSocketProxy) 

Using this module you can forward websocket JSON-RPC 2.0 requests to RPC server.


```
# lib/your-application.pm

use base 'Mojolicious';

sub startup {
    my $self = shift;
    $self->plugin(
        'web_socket_proxy' => {
            actions => [
                ['json_key', {some_param => 'some_value'}]
            ],
            base_path => '/api',
            url => 'http://rpc-host.com:8080/',
        }
    );
}

```

#### INSTALLATION

To install this module, run the following commands:

	perl Makefile.PL
	make
	make test
	make install

#### SUPPORT AND DOCUMENTATION

You can look for information at:

    RT, CPAN's request tracker (report bugs here)
        http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojo-WebSocketProxy

    AnnoCPAN, Annotated CPAN documentation
        http://annocpan.org/dist/Mojo-WebSocketProxy

    CPAN Ratings
        http://cpanratings.perl.org/d/Mojo-WebSocketProxy

    Search CPAN
        http://search.cpan.org/dist/Mojo-WebSocketProxy/


i####COPYRIGHT

Copyright (C) 2016 binary.com
