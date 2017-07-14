package Test2::Harness;
use strict;
use warnings;

use Carp qw/croak/;
use List::Util qw/sum/;
use Time::HiRes qw/sleep/;

use Test2::Harness::Util::HashBase qw{
    -feeder
    -loggers
    -renderers
    -batch_size
    -callback
    -watchers
    -active
    -live
};

sub init {
    my $self = shift;

    croak "'feeder' is a required attribute"
        unless $self->{+FEEDER};

    croak "'renderers' is a required attribute"
        unless $self->{+RENDERERS};

    croak "'renderers' must be an array reference'"
        unless ref($self->{+RENDERERS}) eq 'ARRAY';

    $self->{+BATCH_SIZE} ||= 1000;
}

sub run {
    my $self = shift;

    while (1) {
        $self->{+CALLBACK}->() if $self->{+CALLBACK};
        my $complete = $self->{+FEEDER}->complete;
        $self->iteration();
        last if $complete;
        sleep 0.02;
    }

    my(@fail, @pass);
    for my $job_id (sort keys %{$self->{+WATCHERS}}) {
        my $watcher = $self->{+WATCHERS}->{$job_id};

        if ($watcher->fail) {
            push @fail => $watcher->job->file;
        }
        else {
            push @pass => $watcher->job->file;
        }
    }

    return {
        fail => \@fail,
        pass => \@pass,
    }
}

sub iteration {
    my $self = shift;

    my $live = $self->{+LIVE};

    while (1) {
        # Track active watchers in a second hash, this avoids looping over all
        # watchers each iteration.
        for my $job_id (sort keys %{$self->{+ACTIVE}}) {
            my $watcher = $self->{+ACTIVE}->{$job_id};
            next unless $watcher->complete;

            $self->{+FEEDER}->job_completed($job_id);
            delete $self->{+ACTIVE}->{$job_id};
        }

        my @events = $self->{+FEEDER}->poll($self->{+BATCH_SIZE}) or last;

        for my $event (@events) {
            my $job_id = $event->job_id;

            # Log first, before the watchers transform the events.
            $_->log_event($event) for @{$self->{+LOGGERS}};

            if ($job_id) {
                # This will transform the events, possibly by adding facets
                my $watcher = $self->{+WATCHERS}->{$job_id};

                unless ($watcher) {
                    my $job = $event->facet_data->{harness_job}
                        or die "First event for job ($job_id) was not a job start!";

                    $watcher = Test2::Harness::Watcher->new(
                        nested => 0,
                        job => $job,
                        live => $live,
                    );

                    $self->{+WATCHERS}->{$job_id} = $watcher;
                    $self->{+ACTIVE}->{$job_id} = $watcher if $live;
                }

                my $f;
                ($event, $f) = $watcher->process($event);

                next unless $event;

                if ($f && $f->{harness_job_end}) {
                    $f->{harness_job_end}->{file} = $watcher->file;
                    $f->{harness_job_end}->{fail} = $watcher->fail;
                    $f->{harness_job_end}->{skip} = defined $watcher->plan && !$watcher->plan;
                    push @{$f->{info}} => $watcher->fail_info_facet_list;
                }
            }

            # Render it now that the watchers have done their thing.
            $_->render_event($event) for @{$self->{+RENDERERS}};
        }
    }

    return;
}

1;
