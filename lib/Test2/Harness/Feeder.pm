package Test2::Harness::Feeder;
use strict;
use warnings;

use Carp qw/confess/;

use Test2::Harness::Watcher();

use Test2::Harness::Util::HashBase qw{-event_counter_ref};

sub poll { confess "poll() is not implemented for $_[0]" }

sub init {
    my $self = shift;

    unless ($self->{+EVENT_COUNTER_REF}) {
        my $counter = 1;
        $self->{+EVENT_COUNTER_REF} = \$counter;
    }
}

# Default, most feeders will be complete by nature.
sub complete { 1 }

# Most ignore this, some need it
sub job_completed { }

1;
