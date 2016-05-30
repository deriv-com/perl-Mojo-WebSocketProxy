package Mojo::WebSocketProxy::Dispatcher::Config;

use Mojo::Base -base;

my $actions;
my $config;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->{actions} = {%$actions} if $actions;
    $self->{config}  = {%$config}  if $config;
    return $self;
}

sub init {
    my ($self, $in_config) = @_;

    $config  = {};
    $actions = {};
    %$config = %$in_config;
    return;
}

sub add_action {
    my ($self, $action, $order) = @_;
    my $name    = $action->[0];
    my $options = $action->[1];

    $actions->{$name} ||= $options;
    $actions->{$name}->{order} = $order;
    $actions->{$name}->{name}  = $name;

    my $f             = '/home/git/regentmarkets/bom-websocket-api/config/v3/' . $name;
    my $in_validator  = JSON::Schema->new(JSON::from_json(File::Slurp::read_file("$f/send.json")), format => \%JSON::Schema::FORMATS);
    my $out_validator = JSON::Schema->new(JSON::from_json(File::Slurp::read_file("$f/receive.json")), format => \%JSON::Schema::FORMATS);

    $actions->{$name}->{in_validator}  = $in_validator;
    $actions->{$name}->{out_validator} = $out_validator;
    return;
}

1;
