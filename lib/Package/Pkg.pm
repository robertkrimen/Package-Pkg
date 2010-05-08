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
    if ( @_ == 2 ) {
        # FIXME This does not work
        die "This does not work";
        @install{qw/ as into /} = ( $_[0], $_[0], $_[1] );
    }
    else {
        @install{qw/ as code into /} = @_;
    }
    Sub::Install::install_sub( \%install );
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

    my $import = sub {
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
            __PACKAGE__->install( @$install, $package );
        }
    };

    my $package = caller;
    $self->install( import => $import => $package );
}

1;
