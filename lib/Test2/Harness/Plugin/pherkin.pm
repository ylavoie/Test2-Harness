package App::Yath::Plugin::pherkin;
use strict;
use warnings;

our $VERSION = '0.000099';

use Test2::Harness::Util::TestFile;

use IPC::Cmd qw/can_run/;
use parent 'App::Yath::Plugin';

use File::Basename;

my $pherkin_bin = '/usr/local/bin/pherkin';
my $suffix = '.feature';

# Munge the file list found
# Trying to run: 'psql $args $tf->file'
sub munge_files {
    my ($plugin, $testfiles) = @_;
    for my $tf (@$testfiles) {
       if ($tf->file =~ m/[.]feature$/) {
           $tf = Test2::Harness::Util::TestFile->new(
               file => $pherkin_bin,
               queue_args => [ 
                   job_name => $tf->file,
                   +args => [$tf->file],
                   via => [ 'Fork', 'IPC' ]
               ]
           );
       }
    }
}

# Claim our files
sub claim_file {
    my ($plugin, $item) = @_;
    my ($filename, $dirs, $suffix0) = fileparse($item);
    return undef if -d $item;
    return ! ref($suffix) || $suffix eq $suffix0 
        ? Test2::Harness::Util::TestFile->new(file => $item) : undef;
}

1;
