package App::Yath::Command::dummy2;
use strict;
use warnings;

our $VERSION = '0.001100';

use parent 'App::Yath::Command::dummy';
use Test2::Harness::Util::HashBase;
use App::Yath::Options;

sub internal_only { 0 }
sub summary       { "Dummy Command" }
sub description   { "Dummy Command" }
sub group         { "Dummy" }

include_options 'App::Yath::Command::dummy' => sub {
    my $option = shift;

    return 1 unless $option->name =~ m/2/;
    return 0;
};

sub run {
    my $self = shift;

    print "\nDummy 2!\n";

    return 0;
}

1;
