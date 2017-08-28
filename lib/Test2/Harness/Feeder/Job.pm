package Test2::Harness::Feeder::Job;
use strict;
use warnings;

our $VERSION = '0.001001';

use Carp qw/croak carp/;
use Scalar::Util qw/blessed/;
use Time::HiRes qw/time/;

use Test2::Harness::Job::Dir;

BEGIN { require Test2::Harness::Feeder; our @ISA = ('Test2::Harness::Feeder') }

use Test2::Harness::Util::HashBase qw{
    -_complete

    -job_id
    -run_id
    -dir
};

sub init {
    my $self = shift;

    $self->SUPER::init();

    croak "'job_id' is a required attribute"
        unless $self->{+JOB_ID};

    croak "'run_id' is a required attribute"
        unless $self->{+RUN_ID};

    my $dir = $self->{+DIR} or croak "'dir' is a required attribute";
    unless (blessed($dir) && $dir->isa('Test2::Harness::Job::Dir')) {
        croak "'dir' must be a valid directory" unless -d $dir;

        $dir = $self->{+DIR} = Test2::Harness::Job::Dir->new(
            job_root => $dir,
            run_id   => $self->{+RUN_ID},
            job_id   => $self->{+JOB_ID},
        );
    }
}

sub poll {
    my $self = shift;
    my ($max) = @_;

    return if $self->{+_COMPLETE};

    my @events = $self->{+DIR}->poll($max);

    return @events;
}

sub set_complete {
    my $self = shift;

    $self->{+_COMPLETE} = 1;
    delete $self->{+DIR};

    return $self->{+_COMPLETE};
}

sub complete {
    my $self = shift;

    return $self->{+_COMPLETE};
}

1;
