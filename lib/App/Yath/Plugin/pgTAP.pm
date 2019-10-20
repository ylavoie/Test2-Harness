package App::Yath::Plugin::pgTAP;
use strict;
use warnings;

our $VERSION = '0.000099';

use Test2::Harness::Util::TestFile;

use IPC::Cmd qw/can_run/;
use parent 'App::Yath::Plugin';

use File::Basename;

my $psql_bin = '/usr/bin/psql';
my $suffix;

use Data::Printer;

# Add our options.
# TODO: How can we limit them to files covered by this plugin?
sub options {
    my ($plugin, $settings) = @_;

    return
        {
            spec    => 'pgtap-option=s@',
            action => sub {
                my $self = shift;
                my ($settings, $field, $arg, $opt) = @_;
                return if $arg !~ /^(username|dbname|host|port|suffix|pset|set|psql-bin|schema)=.+/;
                (undef,$psql_bin) = split('=',$arg)
                    if $arg =~ /^psql-bin=.+/;
                (undef,$suffix) = split('=',$arg)
                    if $arg =~ /^suffix=\.(pg|sql|s)/;
                push @{$settings->{'pass'}}, "--$arg"
                    if $arg !~ /suffix|psql-bin/;
            },
            used_by => {runner => 1, jobs => 1},
            section => 'Harness Options',
            usage   => ['--pgtap-option option=value'],
            summary => ['Specify additional pgtap options', 'this option may be given multiple times'],
        };
}

# Munge the file list found
# Trying to run: 'psql $args $tf->file'
sub munge_files {
    my ($plugin, $testfiles) = @_;
    for my $tf (@$testfiles) {
       if ($tf->file =~ m/[.]pg$/) {
           $tf = Test2::Harness::Util::TestFile->new(
               file => $psql_bin,
               queue_args => [ 
                   job_name => $tf->file,
                   +args => ['--no-psqlrc', '--no-align', '--quiet',
                             '--pset', 'pager=off', '--pset', 'tuples_only=true', '--set', 'ON_ERROR_STOP=1',
                             '--file', $tf->file],
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
