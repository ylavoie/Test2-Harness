package Test2::Harness::Renderer::Formatter;
use strict;
use warnings;

use Carp qw/croak/;

use Test2::Harness::Util::JSON qw/encode_pretty_json/;

BEGIN { require Test2::Harness::Renderer; our @ISA = ('Test2::Harness::Renderer') }
use Test2::Harness::Util::HashBase qw{
    -formatter
    -show_run_info
    -show_job_info
    -show_job_launch
    -show_job_end
};

sub init {
    my $self = shift;

    croak "The 'formatter' attribute is required"
        unless $self->{+FORMATTER};

    $self->{+SHOW_JOB_END} = 1 unless defined $self->{+SHOW_JOB_END};
}

sub render_event {
    my $self = shift;
    my ($event) = @_;

    my $f = $event->{facet_data};

    $f->{harness} = {%$event};
    delete $f->{harness}->{facet_data};

    if ($self->{+SHOW_RUN_INFO} && $f->{harness_run}) {
        my $run = $f->{harness_run};

        push @{$f->{info}} => {
            tag       => 'RUN INFO',
            details   => encode_pretty_json($run),
        };
    }

    if ($f->{harness_job_launch}) {
        my $job = $f->{harness_job};

        $f->{harness}->{job_id} ||= $job->{job_id};

        if ($self->{+SHOW_JOB_LAUNCH}) {
            push @{$f->{info}} => {
                tag       => 'LAUNCH',
                debug     => 0,
                important => 1,
                details   => $job->file,
            };
        }

        if ($self->{+SHOW_JOB_INFO}) {
            push @{$f->{info}} => {
                tag     => 'JOB INFO',
                details => encode_pretty_json($job),
            };
        }
    }

    if ($f->{harness_job_end}) {
        my $job  = $f->{harness_job};
        my $skip = $f->{harness_job_end}->{skip};
        my $fail = $f->{harness_job_end}->{fail};
        my $file = $f->{harness_job_end}->{file};

        $f->{harness}->{job_id} ||= $job->{job_id};

        if ($self->{+SHOW_JOB_END}) {
            unshift @{$f->{info}} => {
                tag => $skip ? 'SKIPPED' : $fail ? 'FAILED' : 'PASSED',
                debug     => $fail,
                important => 1,
                details   => $file,
            };
        }
    }

    my $num = $f->{assert} && $f->{assert}->{number} ? $f->{assert}->{number} : undef;

    $self->{+FORMATTER}->write($event, $num, $f);
}

1;
