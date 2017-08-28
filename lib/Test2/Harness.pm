package Test2::Harness;
use strict;
use warnings;

our $VERSION = '0.001001';

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
    -jobs
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
            push @fail => $watcher->job;
        }
        else {
            push @pass => $watcher->job;
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
    my $jobs = $self->{+JOBS};

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
            next if $jobs && !$jobs->{$job_id};

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

                    my $plan = $watcher->plan;
                    $f->{harness_job_end}->{skip} = $plan->{details} || "No reason given" if $plan && !$plan->{count};

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

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Harness - Test2 Harness designed for the Test2 event system

=head1 DESCRIPTION

=back

=head1 SOURCE

The source code repository for Test2-Harness can be found at
F<http://github.com/Test-More/Test2-Harness/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2017 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
