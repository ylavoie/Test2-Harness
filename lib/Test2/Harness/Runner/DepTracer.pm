package Test2::Harness::Runner::DepTracer;
use strict;
use warnings;

our $VERSION = '0.001100';

use Test2::Harness::Util::HashBase qw/
    -_on
    -exclude
    -dep_map
    -loaded
    -my_require
    -real_require
    -_my_inc
/;

my %DEFAULT_EXCLUDE = (
    'warnings.pm' => 1,
    'strict.pm'   => 1,
);

sub start {
    my $self = shift;

    unshift @INC => $self->my_inc;

    $self->{+_ON} = 1;
}

sub stop {
    my $self = shift;

    $self->{+_ON} = 0;

    my $inc = $self->{+_MY_INC} or return 0;

    @INC = grep { !(ref($_) && $inc == $_) } @INC;
    return 0;
}

sub my_inc {
    my $self = shift;

    return $self->{+_MY_INC} if $self->{+_MY_INC};

    my $exclude = $self->{+EXCLUDE} ||= {%DEFAULT_EXCLUDE};
    my $dep_map = $self->{+DEP_MAP} ||= {};
    my $loaded  = $self->{+LOADED}  ||= {};

    return $self->{+_MY_INC} ||= sub {
        my ($this, $file) = @_;

        print "LOAD INC: $file\n";

        return unless $self->{+_ON};
        return unless $file =~ m/^[_a-z]/i;
        return if $exclude->{$file};

        my $loaded_by = $self->loaded_by;
        push @{$dep_map->{$file}} => $loaded_by;
        $loaded->{$file}++;

        return;
    };
}

sub clear_loaded { %{$_[0]->{+LOADED}} = () }

my %REQUIRE_CACHE;

sub init {
    my $self = shift;

    my $exclude = $self->{+EXCLUDE} ||= { %DEFAULT_EXCLUDE };

    my $stash = \%CORE::GLOBAL::;
    # We use a string in the reference below to prevent the glob slot from
    # being auto-vivified by the compiler.
    $self->{+REAL_REQUIRE} = exists $stash->{require} ? \&{'CORE::GLOBAL::require'} : undef;

    my $dep_map = $self->{+DEP_MAP} ||= {};
    my $loaded  = $self->{+LOADED} ||= {};
    my $inc = $self->my_inc;

    my $require = $self->{+MY_REQUIRE} = sub {
        my ($file) = @_;

        my $loaded_by = $self->loaded_by;

        my $real_require = $self->{+REAL_REQUIRE};
        unless($real_require) {
            my $caller = $loaded_by->[0];
            $real_require = $REQUIRE_CACHE{$caller} ||= eval "package $caller; sub { CORE::require(\$_[0]) }" or die $@;
        }

        goto &$real_require unless $self->{+_ON};

        if ($file =~ m/^[_a-z]/i) {
            unless ($exclude->{$file}) {
                push @{$dep_map->{$file}} => $loaded_by;
                $loaded->{$file}++;
            }
        }

        if (!ref($INC[0]) || $INC[0] != $inc) {
            @INC = (
                $inc,
                grep { !(ref($_) && $inc == $_) } @INC,
            );
        }

        local @INC = @INC[1 .. $#INC];

        $real_require->(@_);
    };

    {
        no strict 'refs';
        no warnings 'redefine';
        *{'CORE::GLOBAL::require'} = $require;
    }
}

sub loaded_by {
    my $level = 1;

    while(my @caller = caller($level++)) {
        next if $caller[0] eq __PACKAGE__;

        return [$caller[0], $caller[1]];
    }

    return ['', ''];
}

1;

__END__


=pod

=encoding UTF-8

=head1 NAME

Test2::Harness::Runner::DepTracer - Tool for tracing module dependancies as
they are loaded.

=head1 DESCRIPTION

B<PLEASE NOTE:> Test2::Harness is still experimental, it can all change at any
time. Documentation and tests have not been written yet!

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

Copyright 2019 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
