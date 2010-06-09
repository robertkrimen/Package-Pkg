use strict;
use warnings;

use Test::Most 'no_plan';

package Apple;

sub apple {
    return 'apple';
}

sub xyzzy {
    return 'xyzzy';
}

package Xyzzy;

sub frobozz {
    return 'frobozz';
}

package main;

use Package::Pkg;

pkg->install( 'Xyzzy::frobozz' => 'Apple::frobozz' );
is( Apple->frobozz, 'frobozz' );

pkg->install( sub { 'banana' }, 'Apple::banana' );
is( Apple->banana, 'banana' );

pkg->install( sub { 'cherry' }, 'Apple', 'cherry' );
is( Apple->cherry, 'cherry' );

sub grape { 'grape' }

pkg->install( 'grape', 'Apple::' );
is( Apple->grape, 'grape' );

pkg->install( 'grape', 'Apple::grape1' );
is( Apple->grape1, 'grape' );

pkg->install( 'grape', 'Apple::grape1::' );
is( Apple::grape1->grape, 'grape' );

# From dox

#pkg->install( code => sub { ... } , as => 'Banana::magic' )
#pkg->install( code => sub { ... } , into => 'Banana::magic' ) # Bzzzt! Throws an error!

{
    no warnings 'redefine';

    my $code = sub {};
    pkg->install( code => $code, as => 'Banana::magic' );
    is( $code, \&Banana::magic );
    *Banana::magic = sub {};

    throws_ok { pkg->install( code => sub { } , into => 'Banana::magic' ) } qr/^Missing as/;

    # Install the subroutine C<Apple::xyzzy> as C<Banana::magic>
    pkg->install( code => 'Apple::xyzzy', as => 'Banana::magic' );
    is( \&Apple::xyzzy, \&Banana::magic );
    *Banana::magic = sub {};

    pkg->install( code => 'Apple::xyzzy', into => 'Banana', as => 'magic' );
    is( \&Apple::xyzzy, \&Banana::magic );
    *Banana::magic = sub {};

    pkg->install( from => 'Apple', code => 'xyzzy', as => 'Banana::magic' );
    is( \&Apple::xyzzy, \&Banana::magic );
    *Banana::magic = sub {};

    pkg->install( from => 'Apple', code => 'xyzzy', into => 'Banana', as => 'magic' );
    is( \&Apple::xyzzy, \&Banana::magic );
    *Banana::magic = sub {};

    # Install the subroutine C<Apple::xyzzy> as C<Banana::xyzzy>
    pkg->install( code => 'Apple::xyzzy', as => 'Banana::xyzzy' );
    is( \&Apple::xyzzy, \&Banana::xyzzy );
    *Banana::xyzzy = sub {};

    pkg->install( code => 'Apple::xyzzy', into => 'Banana' );
    is( \&Apple::xyzzy, \&Banana::xyzzy );
    *Banana::xyzzy = sub {};

    pkg->install( from => 'Apple', code => 'xyzzy', as => 'Banana::xyzzy' );
    is( \&Apple::xyzzy, \&Banana::xyzzy );
    *Banana::xyzzy = sub {};

    pkg->install( from => 'Apple', code => 'xyzzy', into => 'Banana' );
    is( \&Apple::xyzzy, \&Banana::xyzzy );
    *Banana::xyzzy = sub {};
}

{
    no warnings 'redefine';
    my $code = sub {};

    *Banana::xyzzy = sub {};
    pkg->install( $code => 'Banana::xyzzy' );
    is( $code, \&Banana::xyzzy );

    *Banana::xyzzy = sub {};
    pkg->install( 'Apple::apple' => 'Banana::xyzzy' );
    is( \&Apple::apple, \&Banana::xyzzy );

    pkg->install( 'Apple::apple' => 'Banana::' );
    throws_ok { pkg->install( $code => 'Banana::' ) } qr/^Missing as/;
}

{
    no warnings 'redefine';
    my $code = sub {};

    *Banana::xyzzy = sub {};
    pkg->install( $code => 'Banana', 'xyzzy' );
    is( $code, \&Banana::xyzzy );

    *Banana::xyzzy = sub {};
    pkg->install( $code => 'Banana::', 'xyzzy' );
    is( $code, \&Banana::xyzzy );

    *Banana::xyzzy = sub {};
    pkg->install( 'Apple::apple' => 'Banana', 'xyzzy' );
    is( \&Apple::apple, \&Banana::xyzzy );

    *Banana::xyzzy = sub {};
    pkg->install( 'Apple::apple' => 'Banana::', 'xyzzy' );
    is( \&Apple::apple, \&Banana::xyzzy );
}
