package App::Yath::Plugin::pgTAP;

use strict;
use warnings;

our $VERSION = '0.001100';

use parent 'App::Yath::Plugin';
use App::Yath::Options;

option_group {prefix => 'pgtap', category => "Plugin pgTAP"} => sub {

    option dbname => (
      type          => 's',
      long_examples => [' DBNAME' ],
      description   => 'The database to which to connect to run the tests. Defaults to the value of the $PGDATABASE environment variable or, if not set, to the system username.',
    );

    option username => (
      type          => 's',
      long_examples => [' USERNAME' ],
      description   => 'The PostgreSQL username to use to connect to PostgreSQL. If not specified, no username will be used, in which case psql will fall back on either the $PGUSER environment variable or, if not set, the system username.',
    );

    option host => (
      type          => 's',
      long_examples => [' HOST' ],
      description   => 'Specifies the host name of the machine to which to connect to the PostgreSQL server. If the value begins with a slash, it is used as the directory for the Unix-domain socket. Defaults to the value of the $PGDATABASE environment variable or, if not set, the local host.',
    );

    option port => (
      type          => 's',
      long_examples => [' PORT' ],
      default       => 5432,
      description   => 'Specifies the TCP port or the local Unix-domain socket file extension on which the server is listening for connections. Defaults to the value of the $PGPORT environment variable or, if not set, to the port specified at the time psql was compiled, usually 5432.',
    );

    option pset => (
      type          => 'm',
      long_examples => [' PSET' ],
      description   => 'Specifies a hash of printing options in the style of \pset in the psql program. See the psql documentation for details on the supported options.',
    );

    option set => (
      type          => 'm',
      long_examples => [' SET' ],
      description   => 'Specifies a hash of options in the style of \set in the psql program. See the psql documentation for details on the supported options.',      action        => \&_pgtap_action
    );

    option search_path => (
      type          => 's',
      default       => 'tap',
      long_examples => [' public,tap,pg_catalog' ],
      description   => ['The schema search path to use during the execution of the tests.',
                        'Useful for overriding the default search path if you have pgTAP',
                        'installed in a schema not included in that search path']
    );

    option suffix => (
      type          => 's',
      default       => '.pg',
      long_examples => [' .pg' ],
      description   => 'File suffix of pgTAP test files',
      action        => sub {
        #warn
        my ($prefix, $field, $raw, $norm, $slot, $settings, $handler) = @_;

        die "$raw is not an allowed extention"
          unless $raw =~ /\.(pg|sql|s)/;

        $handler->($slot,$raw);
      }
    );

    option psql => (
      type          => 's',
      default       => 'psql',
      long_examples => [' psql' ],
      description   => 'The path to the psql command. Defaults to simply "psql", which should work well enough if it\'s in your path.',
    );

    option option => (
        type          => 'm',

        long_examples => [ ' KEY=VALUE' ],

        description   => ['Support prove options syntax for drop-in compatibility',
                          'where KEY=VALUE is one of:',
                          ' psql=PSQL',' dbname=DBNAME', ' username=USERNAME',
                          ' host=HOST', ' port=PORT', ' pset=OPTION=VALUE',
                          ' set=VAR=VALUE', ' schema=SCHEMA', ' match=REGEX',
                          ' search_path=PATH.',
                          ' See the description of each in --pgtap-KEY'
                         ],

        action        => sub {
            my ($prefix, $field, $raw, $norm, $slot, $settings, $handler) = @_;

            return if $raw !~ /^(username|host|port|suffix|dbname|pset|set|psql|schema)=.+/;

            my ($option,$value) = split /=/, $raw, 2;

            if ( $option =~ /p?set/ ) {
                push @{$settings->pgtap->$option}, $value
            } elsif ( $option =~ /suffix/ ) {
                $settings->pgtap->suffix = $value
                    if $value =~ /\.(pg|sql|s)/;
            } else {
                $settings->pgtap->$option = $value;
            }
        }
    );
};

use Test2::Harness::TestFile;

# Munge the file list found
# Trying to run: 'psql $args $tf->file'

sub munge_files {
    my ($plugin, $testfiles, $settings) = @_;

    for my $tf (@$testfiles) {
        if ($tf->file =~ m/[.]pg$/) {
            my @args = ('--no-psqlrc', '--no-align', '--quiet',
                        '--pset', 'pager=off', '--pset', 'tuples_only=true',
                        '--set', 'ON_ERROR_STOP=1');
            #TODO: Schema? match?
            for (qw(username dbname host port)) {
              push @args, "--$_", $settings->pgtap->$_
                if defined $settings->pgtap->$_;
            }
            foreach (@{$settings->pgtap->pset}) {
              push @args, '--pset', $_;
            }
            foreach (@{$settings->pgtap->set}) {
              push @args, '--set', $_;
            }
            $tf = Test2::Harness::TestFile->new(
                 file => $tf->relative,
                 job_class => 'Test2::Harness::Runner::Job::pgTAP',
                 queue_args => [
                     command => $settings->pgtap->psql,
                     binary => 1,
                     +test_args => [@args, ( '--file', $tf->relative )]
                 ]
            );
        }
    }
}

use File::Basename;

# Claim our files
sub claim_file {
    my ($plugin, $item, $settings) = @_;
    my ($filename, $dirs, $suffix0) = fileparse($item);
    return undef if -d $item;
    my $suffix = $settings->pgtap->suffix;
    return $suffix eq $suffix0
        ? Test2::Harness::TestFile->new(file => $item) : undef;
}

1;
