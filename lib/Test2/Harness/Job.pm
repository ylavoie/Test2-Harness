package Test2::Harness::Job;
use strict;
use warnings;

our $VERSION = '0.001001';

use Carp qw/croak/;

use Test2::Harness::Util::HashBase qw{
    -job_id

    -pid

    -file
    -env_vars
    -libs
    -switches
    -args
    -input
    -no_stream
    -no_fork
};

sub init {
    my $self = shift;

    croak "The 'job_id' attribute is required"
        unless $self->{+JOB_ID};

    croak "The 'file' attribute is required"
        unless $self->{+FILE};

    $self->{+ENV_VARS} ||= {};
    $self->{+LIBS}     ||= [];
    $self->{+SWITCHES} ||= [];
    $self->{+ARGS}     ||= [];
    $self->{+INPUT}    ||= '';
}

sub TO_JSON { return { %{$_[0]} } }

1;
