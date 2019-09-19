package App::Yath::Options;
use strict;
use warnings;

our $VERSION = '0.001100';

use App::Yath::Options::Instance;

use Carp qw/croak/;

use App::Yath::Util qw/mod2file/;

sub import {
    my $class  = shift;
    my $caller = caller();

    croak "$caller already has an 'options' method"
        if defined(&{"$caller\::options"});

    my @common;
    my $instance;
    my $options = sub { ($instance //= App::Yath::Options::Instance->new()) };
    my $option  = sub { ($instance //= App::Yath::Options::Instance->new())->_option([caller()], shift(@_), @common ? (%{$common[-1]}) : (), @_) };

    my $group = sub {
        my ($set, $sub) = @_;

        my $common = {@common ? (%{$common[-1]}) : (), %$set};
        push @common => $common;

        my $ok  = eval { $sub->(); 1 };
        my $err = $@;

        pop @common;

        die $err unless $ok;
    };

    my $include = sub {
        my @pkgs   = @_;
        my $filter = ref($pkgs[-1]) eq 'CODE' ? pop @pkgs : undef;

        $instance //= App::Yath::Options::Instance->new();

        for my $pkg (@pkgs) {
            next if $pkg eq $caller;

            require(mod2file($pkg));

            my $options = $pkg->can('options') ? $pkg->options : undef;
            croak "$pkg' does not have any options to include" unless $options;
            $instance->include($options, $filter);
        }

        return;
    };

    {
        no strict 'refs';
        *{"$caller\::options"}         = $options;
        *{"$caller\::option"}          = $option;
        *{"$caller\::option_group"}    = $group;
        *{"$caller\::include_options"} = $include;
    }

    return 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Yath::Options - Tools for defining and tracking yath CLI options.

=head1 DESCRIPTION

This package exports the tools used to provide options for Yath. All exports
act on the singleton instance of L<App::Yath::Options::Instance>.

=head1 SYNOPSIS

    package Yath::App::Options::MyOptions
    use App::Yath::Options;

    option foo => (
        type    => 'list',
        short   => 'f',
        default => 'bar',
    );

    option lib => (
        type        => 'scalar',
        short       => 'I',
        pre_command => 1,
    );

=head1 EXPORTS

All these exports act on the singleton.

=over 4

=item option 'field';

=item option 'field=list';

=item option field => 'list';

=item option field => (type => 'list', ...);

See L<App::Yath::Option> for details on what attributes can be used at
construction.

Prefix will be automatically inserted if this is called from an
L<App::Yath::Plugin(::.+)?> package.

Command name, plugin name, and/or opts_package will be set automatically based
on the calling package.

=item $instance = options();

=item $instance = Yath::App::Options::MyOptions->options();

Get the L<App::Yath::Options::Instance> associated with your options class.

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

Copyright 2019 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
