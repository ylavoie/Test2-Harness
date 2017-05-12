package Test2::Harness::Event;
use strict;
use warnings;

use Carp qw/confess/;

use Test2::Util::Facets2Legacy ':ALL';

use parent 'Test2::Event';
use Test2::Harness::Util::HashBase qw/-facet_data/;

sub init {
    my $self = shift;

    confess("'facet_data' is a required attribute")
        unless $self->{+FACET_DATA};
}

{
    no warnings 'redefine';

    sub causes_fail {
        my $self = shift;
        return 1 if $self->{+FACET_DATA}->{harness}->{exit};
        return $self->Test2::Util::Facets2Legacy::causes_fail(@_);
    }
}

1;
