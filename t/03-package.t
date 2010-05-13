use strict;
use warnings;

use Test::Most;
plan 'no_plan';

use Package::Pkg;

is( pkg->package(qw/ A B C D E F /), 'A::B::C::D::E::F' );
is( pkg->package(qw/ A::B C:::D E::::F /), 'A::B::C::D::E::F' );
is( pkg->package( 'A::' ), 'A::' );
is( pkg->package( '::A' ), 'main::A' );
is( pkg->package( '::' ), '' );
