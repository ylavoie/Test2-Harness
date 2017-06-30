package Test2::Harness::Util::Proc;
use strict;
use warnings;

use Carp qw/croak/;
use POSIX qw/:sys_wait_h/;

use Test2::Harness::Util::HashBase qw/-pid -exit/;

sub init {
    my $self = shift;

    croak "The 'pid' attribute is required"
        unless $self->{+PID};
}

sub complete {
    my $self = shift;

    return 1 if defined $self->{+EXIT};

    $self->wait(WNOHANG);

    return defined $self->{+EXIT};
}

sub wait {
    my $self = shift;
    my ($flags) = @_;

    my $pid = $self->{+PID};

    return -1 if defined $self->{+EXIT};

    local $?;
    my $ret = waitpid($pid, $flags);
    my $exit = $?;
    die "Process $self->{+PID} was already reaped!" if $ret == -1;

    return $ret unless $ret == $pid;
    $exit >>= 8;

    $self->{+EXIT} = $exit;

    return $ret;
}

1;
