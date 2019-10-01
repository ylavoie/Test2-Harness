package Test2::Harness::Collector;
use strict;
use warnings;

use Test2::Harness::Util::HashBase qw{
    <workdir
    <run_id
    <show_runner_output
    <settings
    <run_dir

    <jobs
    <job_list

    <action
};

sub init {
    my $self = shift;

    my $run_dir = File::Spec->catdir($self->{+WORKDIR}, $self->{+RUN_ID});
    die "Could not find run dir" unless -d $run_dir;
    $self->{+RUN_DIR} = $run_dir;
}

sub run {
    my $self = shift;

    while (1) {

    }
}

1;

__END__
use Test2::Harness::Util::File::JSONL;
use Test2::Harness::Util::File::Stream;

use Test2::Harness::Util::HashBase qw/-root -_jobs_file -_err_file -_log_file -tail/;

sub init {
    my $self = shift;

    croak "The 'root' attribute is required"
        unless $self->{+ROOT};

    $self->{+ROOT} = File::Spec->rel2abs($self->{+ROOT});
}

sub log_file {
    my $self = shift;
    return $self->{+_LOG_FILE} ||= Test2::Harness::Util::File::Stream->new(
        name => File::Spec->catfile($self->{+ROOT}, 'output.log'),
        tail => $self->{+TAIL},
    );
}

sub err_file {
    my $self = shift;
    return $self->{+_ERR_FILE} ||= Test2::Harness::Util::File::Stream->new(
        name => File::Spec->catfile($self->{+ROOT}, 'error.log'),
        tail => $self->{+TAIL},
    );
}

sub jobs_file {
    my $self = shift;
    return $self->{+_JOBS_FILE} ||= Test2::Harness::Util::File::JSONL->new(
        name => File::Spec->catfile($self->{+ROOT}, 'jobs.jsonl'),
    );
}

sub err_list { $_[0]->err_file->poll(from => 0) }
sub err_poll { $_[0]->err_file->poll(max  => $_[1]) }

sub log_list { $_[0]->log_file->poll(from => 0) }
sub log_poll { $_[0]->log_file->poll(max  => $_[1]) }

sub job_list { map { Test2::Harness::Job->new(%{$_}) } $_[0]->jobs_file->poll(from => 0) }
sub job_poll { map { Test2::Harness::Job->new(%{$_}) } $_[0]->jobs_file->poll(max => $_[1])}

sub complete { -e File::Spec->catfile($_[0]->{+ROOT}, 'complete') }

1;


