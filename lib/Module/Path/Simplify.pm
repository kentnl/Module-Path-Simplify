use 5.006;    # our
use strict;
use warnings;

package Module::Path::Simplify;

our $VERSION = '0.001000';

# ABSTRACT: Simplify absolute paths for pretty-printing.

# AUTHORITY

sub new {
  my ( $class, @args ) = @_;
  return bless { ref $args[0] ? %{ $args[0] } : @args }, $class;
}

sub simplify {
  my ( $self, $path ) = @_;
  my $result = $self->_find_inc($path);
  return $self->_format_simplified($result) if defined $result;
  return $path;
}

sub aliases {
  my ($self) = @_;
  return ( $self->{aliases} ||= Module::Path::Simplify::_AliasMap->new() );
}

sub pp_aliases {
  my ($self) = @_;
  return qq[\t] . join qq[\n\t], $self->aliases->pretty;
}

sub _find_inc {
  my ( undef, $path, ) = @_;
  my $shortest;
  my $inc;
  my $alias;

  for my $inc_no ( 0 .. $#INC ) {
    my $candidate_inc = $INC[$inc_no];
    next if ref $candidate_inc;
    $candidate_inc =~ s{ /? \z }{/}gsx;
    if ( $path =~ / \A \Q$candidate_inc\E (.*\z) /sx ) {
      my $short = $1;
      if ( not defined $shortest or length $short < length $shortest ) {
        $shortest = $short;
        ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
        $alias = sprintf q[$INC[%d]], $inc_no;
        $inc = $candidate_inc;
      }
    }
  }
  return unless defined $shortest;
  return {
    alias         => $alias,
    relative_path => $shortest,
    display       => $alias,
    alias_path    => $inc,
  };
}

package Module::Path::Simplify::_AliasMap;

sub new {
  my ( $class, ) = @_;
  return bless { aliases => {}, display => {} }, $class;
}

# Note; display here is the default display value.
# User specific overrides must be independent as
# not to create alias entries for things that aren't seen.
## no critic (NamingConventions::ProhibitAmbiguousNames)
sub set {
  my ( $self, $alias, $path, $display ) = @_;
  $self->{aliases}->{$alias} = {
    path => $path,
    ( $display ? ( display => $display ) : () ),
  };
  return;
}

sub get {
  my ( $self, $alias ) = @_;
  return $self->{aliases}->{$alias};
}

sub names {
  my ($self) = @_;
  my (@list) = sort keys %{ $self->{aliases} };
  return @list;
}

sub get_path {
  my ( $self, $alias ) = @_;
  return $self->{aliases}->{$alias}->{'path'}
    if exists $self->{aliases}->{$alias};
  return;
}

# Again, note: this sets the user override, which is only
# to be used when the alias is actually vivified.
sub set_display {
  my ( $self, $alias, $display ) = @_;
  $self->{display}->{$alias} = $display;
  return;
}

sub get_display {
  my ( $self, $alias ) = @_;
  return $self->{display}->{$alias} if exists $self->{display}->{$alias};
  return $self->{aliases}->{$alias}->{display}
    if exists $self->{aliases}->{$alias}
    and exists $self->{aliases}->{$alias}->{display};
  return $alias;
}

sub get_path_suffixed {
  my ( $self, $alias ) = @_;
  if ( $alias eq $self->get_display($_) ) {
    return $self->get_path($alias);
  }
  return sprintf q[%s (%s)], $self->get_path($alias), $alias;
}

sub pretty {
  my ($self) = @_;
  my $max;
  for my $name ( $self->names ) {
    $max = length $name if not defined $max or length $name > $max;
  }
  return map { sprintf "%${max}s => %s", $self->get_display($_), $self->get_path_suffixed($_) } $self->names;
}

1;
