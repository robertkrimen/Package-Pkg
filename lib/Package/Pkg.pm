package Package::Pkg;
# ABSTRACT: Handy package munging utilities

=head1 SYNOPSIS

First, import a new keyword: C<pkg>

    use Package::Pkg;

Package name formation:

    pkg->name( 'Xy', 'A' ) # Xy::A
    pkg->name( $object, qw/ Cfg / ); # (ref $object)::Cfg

Subroutine installation:

    pkg->install( sub { ... } => 'MyPackage::myfunction' );

    # myfunction in MyPackage is now useable
    MyPackage->myfunction( ... );

Subroutine exporting:

    package MyPackage;

    use Package::Pkg;

    sub this { ... }

    # Setup an exporter (literally sub import { ... }) for
    # MyPackage, exporting 'this' and 'that'
    pkg->export( that => sub { ... }, 'this' );

    package main;

    use MyPackage;

    this( ... );

    that( ... );

=head1 DESCRIPTION

Package::Pkg is a collection of useful, miscellaneous package-munging utilities. Functionality is accessed via the imported C<pkg> keyword, although you can also invoke functions directly from the package (C<Package::Pkg>)

=head1 USAGE

=head2 pkg->install( ... )

Install a subroutine, similar to L<Sub::Install> (and actually using that module to do the dirty work)

=head2 $package = pkg->name( <part>, [ <part>, ..., <part> ] )

Return a namespace composed by joining each <part> with C<::>

Superfluous/redundant C<::> are automatically cleaned up and stripped from the resulting $package

If the first part leads with a C<::>, the the calling package will be prepended to $package

    pkg->name( 'Xy', 'A::', '::B' )      # Xy::A::B
    pkg->name( 'Xy', 'A::' )             # Xy::A::
    
    {
        package Zy;

        pkg->name( '::', 'A::', '::B' )  # Zy::A::B
        pkg->name( '::Xy::A::B' )        # Zy::Xy::A::B
    }

In addition, if any part is blessed, C<name> will resolve that part to the package that the part makes reference to:

    my $object = bless {}, 'Xyzzy';
    pkg->name( $object, qw/ Cfg / );     # Xyzzy::Cfg

=head1 SEE ALSO

L<Sub::Install>

L<Sub::Exporter>

=cut

use strict;
use warnings;

require Mouse::Util;
require Sub::Install;
use Try::Tiny;
use Carp;

our $pkg = __PACKAGE__;
sub pkg { $pkg }
__PACKAGE__->export( pkg => \&pkg );

{
    no warnings 'once';
    *package = \&name;
}

sub name {
    my $self = shift;
    my $package = join '::', map { ref $_ ? ref $_ : $_ } @_;
    $package =~ s/:{2,}/::/g;
    return '' if $package eq '::';
    if ( $package =~ m/^::/ ) {
        my $caller = caller;
        $package = "$caller$package";
    }
    return $package;
}

sub load_name {
    my $self = shift;
    my $package = $self->name( @_ );
    $self->load( $package );
    return $package;
}

sub _is_package_loaded ($) { return Mouse::Util::is_class_loaded( $_[0] ) }

sub _package2pm ($) {
    my $package = shift;
    my $pm = $package . '.pm';
    $pm =~ s{::}{/}g;
    return $pm;
}

sub loader {
    my $self = shift;
    require Package::Pkg::Loader;
    my $namespacelist = ref $_[0] eq 'ARRAY' ? shift : [ splice @_, 0, @_ ];
    Package::Pkg::Loader->new( namespacelist => $namespacelist, @_ );
}

sub load {
    my $self = shift;
    my $package = @_ > 1 ? $self->name( @_ ) : $_[0];
    return Mouse::Util::load_class( $package );
}

sub softload {
    my $self = shift;
    my $package = @_ > 1 ? $self->name( @_ ) : $_[0];
    
    return $package if _is_package_loaded( $package );

    my $pm = _package2pm $package;

    return $package if try {
        local $SIG{__DIE__};
        require $pm;
        return 1;
    }
    catch {
        unless (/^Can't locate \Q$pm\E in \@INC/) {
            confess "Couldn't load package ($package) because: $_";
        }
        return;
    };
}

# pkg->install( name => sub { ... } => 
sub install {
    my $self = shift;
    my %install;
    if      ( @_ == 1 ) { %install = %{ $_[0] } }
    elsif   ( @_ == 2 ) { @install{qw/ code into /} = @_ }
    elsif   ( @_ == 3 ) { @install{qw/ code into as /} = @_ }
    else                { %install = @_ }

    my ( $from, $code, $into, $_into, $as, ) = @install{qw/ from code into _into as /};
    undef %install;

    die "Missing code" unless defined $code;

    if ( ref $code eq 'CODE' ) {
        die "Invalid (superfluous) from ($from) with code reference" if defined $from;
    }
    else {
        if ( defined $from )
            { die "Invalid code ($code) with from ($from)" if $code =~ m/::/ }
        elsif ( $code =~ m/::/)
            { ( $from, $code ) = $self->split2( $code ) }
        else                    
            { $from = caller }
    }

    if ( defined $as && $as =~ m/::/) {
        die "Invalid as ($as) with into ($into)" if defined $into;
        ( $into, $as ) = $self->split2( $as );
    }
    elsif ( defined $into && ! defined $as ) {
        if ( $into =~ s/::$// ) { }
        else {
            ( $into, $as ) = $self->split2( $into );
        }
    }
    elsif ( defined $_into && ! defined $into ) {
        $into = $_into;
    }

    if      ( defined $as ) {}
    elsif   ( ! ref $code ) { $as = $code }
    else                    { die "Missing as" }

    die "Missing into" unless defined $into;

    @install{qw/ code into as /} = ( $code, $into, $as );
    $install{from} = $from if defined $from;
    Sub::Install::install_sub( \%install );
}

sub split {
    my $self = shift;
    my $target = shift;
    return unless defined $target && length $target;
    return split m/::/, $target;
}

sub split2 {
    my $self = shift;
    return unless my @split = $self->split( @_ );
    return join '::', @split if 1 == @split;
    my $name = pop @split;
    return( join( '::', @split ), $name );
}

sub export {
    my $self = shift;
    my $exporter = $self->exporter( @_ );

    my $package = caller;
    $self->install( code => $exporter, into => "${package}::import" );
}

sub exporter {
    my $self = shift;
    my ( %index, %group, $default_export );
    %group = ( default => [], optional => [], all => [] );
    $default_export = 1;
    while ( @_ ) {
        local $_ = shift;
        my ( $group, @install );
        if      ( $_ eq '-' )       { undef $default_export }
        elsif   ( $_ eq '+' )       { $default_export = 1 }
        elsif   ( s/^\+// )         { $group = 'default' }
        elsif   ( s/^\-// )         { $group = 'optional' }
        elsif   ( $default_export ) { $group = 'default' }
        else                        { $group = 'optional' }

        my $name = $_;

        push @install, $name;
        if ( @_ ) {
            my $value = shift;
            if      ( ref $value eq 'CODE' ) { push @install, $value }
            elsif   ( $value =~ s/^<// )     { push @install, $value }
            else                             { unshift @_, $value }
        }

        push @{ $group{$group} ||= [] }, $name;
        $index{$name} = \@install;
    }
    $group{all} = [ map { @$_ } @group{qw/ default optional /} ];

    my $exporter = sub {
        my ( $class ) = @_;

        my $package = caller;
        my @arguments = splice @_, 1;
    
        my @exporting;
        if ( ! @arguments ) {
            push @exporting, @{ $group{default} };
        }
        else {
            @exporting = @arguments;
        }

        for my $name ( @exporting ) {
            my $install = $index{$name} or die "Unrecognized export ($name)";
            my $as = $install->[0];
            my $code = $install->[1] || "${class}::$as";
            __PACKAGE__->install( as => $as, code => $code, into => $package );
        }
    };

    return $exporter;
}

1;
