package Test2::Harness::Renderer;
use strict;
use warnings;

use Carp qw/croak/;

sub render_event { croak "$_[0] forgot to override 'render_event()'" }

1;
