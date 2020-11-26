package Test2::Harness::Runner::Job::pgTAP;

use strict;
use warnings;

our $VERSION = '0.001100';

use Test2::Harness::Util::HashBase;
use parent 'Test2::Harness::Runner::Job';
use Test2::Harness::Util qw/open_file/;

sub spawn_params {
    my $self = shift;

    my $command = [$self->{task}->{command}, $self->args];

    my $out_fh = open_file($self->out_file, '>');
    my $err_fh = open_file($self->err_file, '>');
    my $in_fh  = open_file($self->in_file,  '<');

    return {
        command => $command,
        stdin   => $in_fh,
        stdout  => $out_fh,
        stderr  => $err_fh,
        chdir   => $self->ch_dir(),
        env     => $self->env_vars(),
    };
}

1;
