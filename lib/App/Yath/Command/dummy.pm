package App::Yath::Command::dummy;
use strict;
use warnings;

our $VERSION = '0.001100';

use parent 'App::Yath::Command';
use Test2::Harness::Util::HashBase;
use App::Yath::Options;

sub internal_only { 0 }
sub summary       { "Dummy Command" }
sub description   { "Dummy Command" }
sub group         { "Dummy" }

sub run {
    my $self = shift;

    print "\nDummy!\n";

    return 0;
}

include_options 'App::Yath::Command';
option 'dummy1';
option 'dummy2';

1;
