use 5.014;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Mojo::WebSocketProxy',
    VERSION_FROM     => 'lib/Mojo/WebSocketProxy.pm',
    AUTHOR           => 'Binary.com (binary@cpan.org)',
    ABSTRACT         => 'Perl implementation of websocket JSON-RPC 2.0 proxy',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.014,
    BUILD_REQUIRES   => {
        'Test::More'       => 0,
        'Test::MockModule' => 0,
        'Test::MockObject' => 0,
        'JSON'             => 0,
    },
    PREREQ_PM => {
        'Test::Simple'             => 0.44,
        'Mojolicious'              => 0,
        'MojoX::JSON::RPC'         => 0,
        'Guard'                    => 0,
        'JSON'                     => 0,
        'Data::UUID'               => 0,
        'Test::More'               => 0,
        'Test::Mojo'               => 0,
        'Test::MockModule'         => 0,
        'Test::MockObject'         => 0,
        'Time::Out'                => 0,
        'Class::Method::Modifiers' => 0,
    },
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 6.64,
    },
    dist => {
        COMPRESS => 'gzip -9f',
        SUFFIX   => 'gz',
    },
    META_MERGE => {
        requires  => {perl => 5.014},
        resources => {
            homepage   => 'https://github.com/binary-com/perl-Mojo-WebSocketProxy',
            bugtracker => 'https://github.com/binary-com/perl-Mojo-WebSocketProxy/issues',
            repository => 'git://github.com/binary-com/perl-Mojo-WebSocketProxy',
            license    => 'http://dev.perl.org/licenses/',
        },
        x_contributors => ['Evgeniy Vostrov <vostrov.e@gmail.com>'],
    },
);
