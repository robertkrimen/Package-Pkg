package Package::Pkg;
# ABSTRACT: Package::Pkg! Package::Pkg!

use strict;
use warnings;

require Class::MOP;
require Sub::Install;

# pkg->install( name => sub { ... } => 
sub install {
    my $self = shift;
    my %install;
    if      ( @_ == 1 ) { %install = %{ $_[0] } }
    elsif   ( @_ == 2 ) { @install{qw/ code into /} = @_ }
    elsif   ( @_ == 3 ) { @install{qw/ code into as /} = @_ }
    else                { %install = @_ }

    my ( $from, $code, $into, $as ) = @install{qw/ from code into as /};
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

our $pkg = __PACKAGE__;

sub pkg { $pkg }

__PACKAGE__->export( pkg => \&pkg );

sub load {
    my $self = shift;
    my ( $package ) = @_;
    return Class::MOP::load_class( $package );
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
        if ( ref $_[0] eq 'CODE' ) { push @install, shift }

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
            __PACKAGE__->install( as => $install->[0], code => $install->[1], into => $package );
        }
    };

    return $exporter;
}

1;
