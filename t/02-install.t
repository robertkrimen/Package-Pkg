use strict;
use warnings;

use Test::Most;
plan 'no_plan';

package Apple;

sub apple {
    return 'apple';
}

package Xyzzy;

sub xyzzy {
    return 'xyzzy';
}

package main;

use Package::Pkg;

pkg->install( 'Xyzzy::xyzzy' => 'Apple::xyzzy' );
is( Apple->xyzzy, 'xyzzy' );

pkg->install( sub { 'banana' }, 'Apple::banana' );
is( Apple->banana, 'banana' );

pkg->install( sub { 'cherry' }, 'Apple', 'cherry' );
is( Apple->cherry, 'cherry' );

sub grape { 'grape' }

pkg->install( 'grape', 'Apple' );
is( Apple->grape, 'grape' );

pkg->install( 'grape', 'Apple::grape1' );
is( Apple->grape1, 'grape' );

pkg->install( 'grape', 'Apple::grape1::' );
is( Apple::grape1->grape, 'grape' );

1;

