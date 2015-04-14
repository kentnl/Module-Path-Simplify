use 5.006;    # our
use strict;
use warnings;

package Module::Path::Simplify;

our $VERSION = '0.001000';

# ABSTRACT: Simplify absolute paths for pretty-printing.

# AUTHORITY

=method C<new>

Create a C<simplifier> object.

=cut

sub new {
  my ( $class, @args ) = @_;
  return bless { ref $args[0] ? %{ $args[0] } : @args }, $class;
}

=method C<simplify>

Return a simplified version of a path, or the path itself
if there are no simplifications available

  print $simpl->simplify( $INC{'Test/More.pm'} )

=cut

sub simplify {
  my ( $self, $path ) = @_;

  my ( $best, ) = sort { length $a->{relative_path} <=> length $b->{relative_path} } grep { defined }
    $self->_find_config($path),
    $self->_find_inc($path);

  if ( defined $best ) {
    $self->aliases->set( $best->{alias}, $best->{alias_path}, $best->{display}, );
    my $real_display = $self->aliases->get_display( $best->{alias} );
    return sprintf q[%s/%s], $real_display, $best->{relative_path};
  }
  return $path;
}

=method C<aliases>

Returns the internal alias tracking object.

=cut

sub aliases {
  my ($self) = @_;
  return ( $self->{aliases} ||= Module::Path::Simplify::_AliasMap->new() );
}

=method C<pp_aliases>

Return a string detailing the used simplification aliases
and where they map to. ( And possibly their internal identifier )

=cut

sub pp_aliases {
  my ($self) = @_;
  return qq[\t] . join qq[\n\t], $self->aliases->pretty;
}

sub _find_config {
  my ( undef, $path, ) = @_;
  require Config;
  my (@try) = (
    { display => 'SS', key => 'sitelib_stem' },
    { display => 'SP', key => 'siteprefix' },
    { display => 'VS', key => 'vendorlib_stem' },
    { display => 'VP', key => 'vendorprefix' },
    { display => 'PP', key => 'prefix' },
    { display => 'SA', key => 'sitearch' },
    { display => 'SL', key => 'sitelib' },
    { display => 'VA', key => 'vendorarch' },
    { display => 'VL', key => 'vendorlib' },
    { display => 'PA', key => 'archlib' },
    { display => 'PL', key => 'privlib' },
  );
  my $shortest;
  my $lib;
  my $alias;
  my $display;

  for my $job (@try) {
    ## no critic (Variables::ProhibitPackageVars)
    my $candidate_lib = $Config::Config{ $job->{key} };
    next if not defined $candidate_lib or ref $candidate_lib;
    $candidate_lib =~ s{ /? \z }{/}gxs;
    if ( $path =~ / \A \Q$candidate_lib\E (.*\z) /sx ) {
      my $short = $1;
      if ( not defined $shortest or length $short < length $shortest ) {
        $shortest = $short;
        $lib      = $candidate_lib;
        $alias    = 'config.' . $job->{key};
        ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
        $display = '${' . $job->{display} . '}';
      }
    }
  }
  return unless defined $shortest;
  return {
    alias         => $alias,
    relative_path => $shortest,
    display       => $display,
    alias_path    => $lib,
  };
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

=head1 DESCRIPTION

This module aids in simplifying paths to modules you may already have had lying around,
for instance, like in C<%INC>, and aids in compressing them into a format more easily skimmed,
for use in diagnostic reporting such as stack-traces, where legibility of the trace is more important
to you than being able to use path C<URIs> verbatim.

=head1 USAGE

  use Module::Path::Simplify;

  my $simplifier = Module::Path::Simplify->new();

  print $simplifier->simplify( $INC{'Module/Path/Simplify.pm'} )
    # This may output something like $INC[0]/Module/Path/Simplify.pm
    # or even ${VP} or ${SP}, depending on where you installed it.

  print $simplifier->pp_aliases;
    # This will emit a key => value table of all the aliases used so far
    # by this instance, expanding the display setting of the alias to the path matched.
    #
    # In cases where the aliases are different to their display values for better compressability
    # the raw internal alias names will be displayed in parentheses at the end of the line.

