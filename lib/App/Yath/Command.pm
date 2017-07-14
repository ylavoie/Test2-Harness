package App::Yath::Command;
use strict;
use warnings;

use Carp qw/croak/;

use Test2::Harness::Util::HashBase qw/args/;

sub summary { "No Summary" }

sub init {
    my $self = shift;
    $self->{+ARGS} ||= [];
}

sub run {
    my $self = shift;
    my $type = ref($self);

    croak "$type\->run() is not implemented";
}

sub name {
    my $in = shift;
    my $cmd = ref($in) || $in;
    $cmd =~ s/^.*:://g;
    return $cmd;
}

sub usage {
    my $in = shift;
    my $name = $in->name;
    return <<"    EOT";
Usage: $0 $name ...
    EOT
}

1;
