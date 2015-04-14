use 5.006;    # our
use strict;
use warnings;

package Module::Path::Simplify;

our $VERSION = '0.001000';

# ABSTRACT: Simplify absolute paths for pretty-printing.

# AUTHORITY

sub new {
  my ( $class, @args ) = @_;
  my $args = $class->BUILDARGS(@args);
  return bless $args, $class;
}

sub simplify {
  my ( $self, $path ) = @_;

}

sub BUILDARGS {
  my ( $class, @args ) = @_;
  if ( scalar @args == 1 ) {
    unless ( defined $args[0] and 'HASH' eq ref $args[0] ) {
      require Carp;
      Carp::croak(
        "Single parameters to ${class}->new() must be a HASH ref"    #
          . " data => " . $args[0]
      );
    }
    return { %{ $_[0] } };
  }
  elsif ( @args % 2 ) {
    require Carp;
    Carp::croak(
      "The new() method for ${class} expects a hash reference or a"    #
        . " key/value list. You passed an odd number of arguments"
    );
  }
  return {@args};
}

1;
