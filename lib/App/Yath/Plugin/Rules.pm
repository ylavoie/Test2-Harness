package App::Yath::Plugin::Rules;

use strict;
use warnings;

our $VERSION = '0.001100';

use parent 'App::Yath::Plugin';
use App::Yath::Options;
use Carp qw(croak);

my @sequences;

sub _maybe_load_rulesfile {
    my ($self,$rulesfile) = @_;

    if ( defined $rulesfile && -r $rulesfile ) {
        if ( ! eval { require CPAN::Meta::YAML; 1} ) {
           warn "CPAN::Meta::YAML required to process $rulesfile" ;
           return;
        }
        my $layer = $] lt "5.008" ? "" : ":encoding(UTF-8)";
        open my $fh, "<$layer", $rulesfile
            or die "Couldn't open $rulesfile: $!";
        my $yaml_text = do { local $/; <$fh> };
        my $yaml = CPAN::Meta::YAML->read_string($yaml_text)
            or die CPAN::Meta::YAML->errstr;
        return $yaml->[0];
    }
    return;
}

option_group {prefix => 'rules', category => "Plugin Rules"} => sub {

    option file => (
      type          => 's',
      default       => 't/testrules.yml',
      description   => 'Rules for parallel vs sequential processing.',
      action        => sub {
        my ($prefix, $field, $raw, $norm, $slot, $settings, $handler) = @_;
        die "Couldn't open $norm"
          if ! -r $norm;
        $handler->($slot,$norm);
      }
    );
    option rules => (
      type          => 'H',
      default       => sub { return {par => ['**']} },
      action        => sub {
        my ($prefix, $field, $raw, $norm, $slot, $settings, $handler) = @_;

        my %args;
        if ( $raw ) {
            my @rules;
            for ( @{ $raw } ) {
                if (/^par=(.*)/) {
                    push @rules, $1;
                }
                elsif (/^seq=(.*)/) {
                    push @rules, { seq => $1 };
                } else { die "Bad rule $_"; }
            }
            $args{rules} = { par => [@rules] };
        }
        $handler->($slot,%args);
      }
    );
    option schedule => (
      type          => 'H',
      description   => 'Schedule',
    );
    option sequences => (
      type          => 'H',
      description   => 'Sequences',
    );
    post sub {
      my %params = @_;
      my $plugin = 'App::Yath::Plugin::Rules';

      my $settings = $params{settings};
      my $options  = $params{options};

      my $set_by_cli = $options->set_by_cli->{rules};

      my $self = $settings->rules;
      my ($rulesfile) =   defined $self->file ? $self->file :
                          defined($ENV{HARNESS_RULESFILE}) ? $ENV{HARNESS_RULESFILE} :
                          grep { -r } qw(./testrules.yml t/testrules.yml);
      my $rules = $plugin->_maybe_load_rulesfile($rulesfile);
      return if !$rules;

      $self->rules = $rules;

      # Assign rules to files asked
      $self->schedule = $plugin->_set_rules($rules, $params{args});
    }
};

use Test2::Harness::TestFile;

sub munge_files {
    my ($plugin, $testfiles, $settings) = @_;

    # Make sure relative is defined
    $_->{relative} //= $_->relative
      for (@$testfiles);

    # Assign sequence hierarchy
    $plugin->scheduler($testfiles, $settings->rules->schedule);
    warn "munge_files";
}

=x
# Dump of small loaded $schedule
# odd levels are sequential, even are parallel
\ [
    [0] [
        [0] xt/40-dbsetup.t
    ],
    [1] [
        [0] [
            [0] xt/42-account.pg,
            [1] xt/42-admin.pg,
            [2] xt/42-app-module.pg,
            [3] xt/42-arap.pg,
            [4] xt/42-assets.pg
        ]
    ],
    [2] [
        [0] xt/89-dropdb.t
    ]
]
=cut

# TODO: Assign IMMISCIBLE attribute and remove the 'par' levels

sub scheduler {
  my ( $self, $tests, $rule, $sequence, $depth, $index, $names )
   = ( shift, shift, shift, shift, shift // 0, shift // 0, shift // () );

  return if !defined $rule;

  if ( 'ARRAY' eq ref $rule ) {

      return unless @$rule;

      my $type = ( 'par', 'seq' )[ $depth % 2 ];

      # Set sequence name
      my $parent = $names ? join('_',@$names) : '';
      push @$names, "$type$index";
      my $name = join('_',@$names);

      $sequence //= ();
      my $child  = { type => $type, name => $name, children => [] } ;
      push @$sequence, $child;

      my $n = 0;
      for ( @$rule) {
          # Set sequence for the subtrees
          $self->scheduler( $tests, $_, $child->{children}, $depth + 1, $n++, $names );
      }
      pop @$names;
  }
  else {
      # Assign this sequence to the current test
      my $name = join('_',@$names);
      for (@$tests) {
        $_->{_headers}{sequence} = { name => 'testrules', sequence => $name }
          if $_->relative eq $rule;
      }
      push @sequences, $name
        if !($name ~~ @sequences);
  }
}

# Build the scheduler data structure.
#
# SCHEDULER-DATA ::= JOB
#                ||  ARRAY OF ARRAY OF SCHEDULER-DATA
#
# The nested arrays are the key to scheduling. The outer array contains
# a list of things that may be executed in parallel. Whenever an
# eligible job is sought any element of the outer array that is ready to
# execute can be selected. The inner arrays represent sequential
# execution. They can only proceed when the first job is ready to run.
#
# All below are mostly copied from PROVE scheduler, except for _prune_schedule
sub _set_rules {
    my ( $self, $rules, $tests ) = @_;

    my @tests = @$tests;
    my $schedule = $self->_rule_clause( $rules, \@tests );
    while ($self->_prune_schedule( $schedule )){}

    # If any tests are left add them as a sequential block at the end of
    # the run.
    $schedule = [ [$schedule], [@tests] ] if @tests;

    return $schedule;
}

# Remove empty branches
sub _prune_schedule {
  my ( $self, $schedule ) = @_;
  return unless 'ARRAY' eq ref $schedule && @$schedule;
  my $pruned = 0;
  for (my $ti = 0; $ti < @$schedule; $ti++) {
    my $s = $schedule->[$ti];
    next if 'ARRAY' ne ref $s;
    if (@$s) {
      $ti = -1 if $self->_prune_schedule($s);
    } else {
      splice @$schedule, $ti, 1; $ti--;
      $pruned++;
    }
  }
  return $pruned;
}

sub _rule_clause {
    my ( $self, $rule, $tests ) = @_;
    croak 'Rule clause must be a hash'
      unless 'HASH' eq ref $rule;

    my @type = keys %$rule;
    croak 'Rule clause must have exactly one key'
      unless @type == 1;

    my %handlers = (
        par => sub { 1 <= @_ ? [@_] : [ map { [$_] } @_ ]; },
        seq => sub { 1 <= @_ ? [@_] : [ [@_] ] },
    );

    my $handler = $handlers{ $type[0] }
      || croak 'Unknown scheduler type: ', $type[0];
    my $val = $rule->{ $type[0] };

    return $handler->(
        map {
            'HASH' eq ref $_
              ? $self->_rule_clause( $_, $tests )
              : $self->_expand( $_, $tests )
          } 'ARRAY' eq ref $val ? @$val : $val
    );
}

sub _glob_to_regexp {
    my ( $self, $glob ) = @_;
    my $nesting;
    my $pattern;

    while (1) {
        if ( $glob =~ /\G\*\*/gc ) {

            # ** is any number of characters, including /, within a pathname
            $pattern .= '.*?';
        }
        elsif ( $glob =~ /\G\*/gc ) {

            # * is zero or more characters within a filename/directory name
            $pattern .= '[^/]*';
        }
        elsif ( $glob =~ /\G\?/gc ) {

            # ? is exactly one character within a filename/directory name
            $pattern .= '[^/]';
        }
        elsif ( $glob =~ /\G\{/gc ) {

            # {foo,bar,baz} is any of foo, bar or baz.
            $pattern .= '(?:';
            ++$nesting;
        }
        elsif ( $nesting and $glob =~ /\G,/gc ) {

            # , is only special inside {}
            $pattern .= '|';
        }
        elsif ( $nesting and $glob =~ /\G\}/gc ) {

            # } that matches { is special. But unbalanced } are not.
            $pattern .= ')';
            --$nesting;
        }
        elsif ( $glob =~ /\G(\\.)/gc ) {

            # A quoted literal
            $pattern .= $1;
        }
        elsif ( $glob =~ /\G([\},])/gc ) {

            # Sometimes meta characters
            $pattern .= '\\' . $1;
        }
        else {

            # Eat everything that is not a meta character.
            $glob =~ /\G([^{?*\\\},]*)/gc;
            $pattern .= quotemeta $1;
        }
        return $pattern if pos $glob == length $glob;
    }
}

sub _expand {
    my ( $self, $name, $tests ) = @_;

    my $pattern = $self->_glob_to_regexp($name);
    $pattern = qr/^ $pattern $/x;
    my @match = ();

    for ( my $ti = 0; $ti < @$tests; $ti++ ) {
        if ( $tests->[$ti] =~ $pattern ) {
            push @match, splice @$tests, $ti, 1;
            $ti--;
        }
    }

    return @match;
}

=head2 Instance Methods

=head3 C<get_all>

Get a list of all remaining tests.

=cut

sub get_all {
    my $self = shift;
    my @all  = $self->_gather( $self->{schedule} );
    $self->{count} = @all;
    @all;
}

sub _gather {
    my ( $self, $rule ) = @_;
    return unless defined $rule;
    return $rule unless 'ARRAY' eq ref $rule;
    return map { defined() ? $self->_gather($_) : () } map {@$_} @$rule;
}

=head3 C<get_job>

Return the next available job as L<TAP::Parser::Scheduler::Job> object or
C<undef> if none are available. Returns a L<TAP::Parser::Scheduler::Spinner> if
the scheduler still has pending jobs but none are available to run right now.

=cut

sub get_job {
    my $self = shift;
    $self->{count} ||= $self->get_all;
    my @jobs = $self->_find_next_job( $self->{schedule} );
    if (@jobs) {
        --$self->{count};
        return $jobs[0];
    }

    #return TAP::Parser::Scheduler::Spinner->new
    warn 'Spinner' if $self->{count};
    return []
      if $self->{count};

    return;
}

sub _not_empty {
    my $ar = shift;
    return 1 unless 'ARRAY' eq ref $ar;
    for (@$ar) {
        return 1 if _not_empty($_);
    }
    return;
}

sub _is_empty { !_not_empty(@_) }

sub _find_next_job {
    my ( $self, $rule ) = @_;

    my @queue = ();
    my $index = 0;
    while ( $index < @$rule ) {
        my $seq = $rule->[$index];

        # Prune any exhausted items.
        shift @$seq while @$seq && _is_empty( $seq->[0] );
        if (@$seq) {
            if ( defined $seq->[0] ) {
                if ( 'ARRAY' eq ref $seq->[0] ) {
                    push @queue, $seq;
                }
                else {
                    my $job = splice @$seq, 0, 1, undef;
                    $job->on_finish( sub { shift @$seq } );
                    return $job;
                }
            }
            ++$index;
        }
        else {

            # Remove the empty sub-array from the array
            splice @$rule, $index, 1;
        }
    }

    for my $seq (@queue) {
        if ( my @jobs = $self->_find_next_job( $seq->[0] ) ) {
            return @jobs;
        }
    }

    return;
}

=head3 C<as_string>

Return a human readable representation of the scheduling tree.
For example:

    my @tests = (qw{
        t/startup/foo.t
        t/shutdown/foo.t

        t/a/foo.t t/b/foo.t t/c/foo.t t/d/foo.t
    });
    my $sched = TAP::Parser::Scheduler->new(
        tests => \@tests,
        rules => {
            seq => [
                { seq => 't/startup/*.t' },
                { par => ['t/a/*.t','t/b/*.t','t/c/*.t'] },
                { seq => 't/shutdown/*.t' },
            ],
        },
    );

Produces:

    par:
      seq:
        par:
          seq:
            par:
              seq:
                't/startup/foo.t'
            par:
              seq:
                't/a/foo.t'
              seq:
                't/b/foo.t'
              seq:
                't/c/foo.t'
            par:
              seq:
                't/shutdown/foo.t'
        't/d/foo.t'


=cut

sub as_string {
    my ($self,$schedule) = @_;
    return $self->_as_string( $schedule );
}

sub _as_string {
    my ( $self, $rule, $depth ) = ( shift, shift, shift || 0 );
    my $pad    = ' ' x 2;
    my $indent = $pad x $depth;
    if ( !defined $rule ) {
        return "$indent(undef)\n";
    }
    elsif ( 'ARRAY' eq ref $rule ) {
        return unless @$rule;
        my $type = ( 'par', 'seq' )[ $depth % 2 ];
        return join(
            '', "$indent$type:\n",
            map { $self->_as_string( $_, $depth + 1 ) } @$rule
        );
    }
    else {
        return "$indent'" . $rule->{relative} . "'\n";
    }
}

1;
