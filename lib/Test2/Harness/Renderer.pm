package Test2::Harness::Renderer;
use strict;
use warnings;

our $VERSION = '0.001001';

use Carp qw/croak/;

sub render_event { croak "$_[0] forgot to override 'render_event()'" }

1;
