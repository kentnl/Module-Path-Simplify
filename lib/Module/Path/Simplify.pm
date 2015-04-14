use 5.006;    # our
use strict;
use warnings;

package Module::Path::Simplify;

our $VERSION = '0.001000';

# ABSTRACT: Simplify absolute paths for pretty-printing.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY







sub new {
  my ( $class, @args ) = @_;
  return bless { ref $args[0] ? %{ $args[0] } : @args }, $class;
}










sub simplify {
  my ( $self, $path ) = @_;

  my ( $best, ) = sort { length $a->{relative_path} <=> length $b->{relative_path} } grep { defined }
    $self->_find_config($path),
    $self->_find_inc($path);

  return $path unless defined $best;

  $self->aliases->set( $best->{alias}, $best->{alias_path}, $best->{display}, );
  my $real_display = $self->aliases->get_display( $best->{alias} );
  return sprintf q[%s/%s], $real_display, $best->{relative_path};
}







sub aliases {
  my ($self) = @_;
  return ( $self->{aliases} ||= Module::Path::Simplify::_AliasMap->new() );
}








sub pp_aliases {
  my ($self) = @_;
  return qq[\t] . join qq[\n\t], $self->aliases->pretty;
}

sub _find_config {
  my ( undef, $path, ) = @_;
  my $match_path = _abs_unix_path( $path );
  require Config;
  my (@try) = (
    { display => 'SA', key => 'sitearch' },
    { display => 'SL', key => 'sitelib' },
    { display => 'SS', key => 'sitelib_stem' },
    { display => 'SP', key => 'siteprefix' },

    { display => 'VA', key => 'vendorarch' },
    { display => 'VL', key => 'vendorlib' },
    { display => 'VS', key => 'vendorlib_stem' },
    { display => 'VP', key => 'vendorprefix' },

    { display => 'PP', key => 'prefix' },
    { display => 'PA', key => 'archlib' },
    { display => 'PL', key => 'privlib' },
  );
  my ( $shortest, $lib, $alias, $display );

  for my $job (@try) {
    ## no critic (Variables::ProhibitPackageVars)
    my $candidate_lib = _abs_unix_path( $Config::Config{ $job->{key} } );
    next if not defined $candidate_lib or ref $candidate_lib;
    $candidate_lib =~ s{ /? \z }{/}gxs;
    if ( $match_path =~ / \A \Q$candidate_lib\E (.*\z) /sx ) {
      my $short = $1;

      next if defined $shortest and length $short > length $shortest;
      $shortest = $short;
      $lib      = $candidate_lib;
      $alias    = 'config.' . $job->{key};
      ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
      $display = '${' . $job->{display} . '}';
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

sub _abs_unix_path {
  my ( $path ) = @_;
  return '' unless defined $path;
  require File::Spec;
  return '' unless ( -e $path or File::Spec->file_name_is_absolute($path) );

  # File::Spec's rel2abs does not resolve symlinks
  # we *need* to look at the filesystem to be sure
  require Cwd;
  my $abs_path = Cwd::abs_path($path);

  return $abs_path unless $^O eq 'MSWin32' and $abs_path;

  eval sprintf q[require %s; 1], q[Win32];

  # sometimes we can get a short/longname mix, normalize everything to longnames
  $abs_path = Win32::GetLongPathName($abs_path);

  # Fixup (native) slashes in Config not matching (unixy) slashes in INC
  $abs_path =~ s|\\|/|g;

  return $abs_path;
}

sub _find_inc {
  my ( undef, $path, ) = @_;
  my $match_path = _abs_unix_path( $path );
  my ( $shortest, $inc, $alias );

  for my $inc_no ( 0 .. $#INC ) {
    my $candidate_inc = _abs_unix_path($INC[$inc_no]);
    next if ref $candidate_inc;
    $candidate_inc =~ s{ /? \z }{/}gsx;
    if ( $match_path =~ / \A \Q$candidate_inc\E (.*\z) /sx ) {
      my $short = $1;
      next if defined $shortest and length $short > length $shortest;

      $shortest = $short;
      ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
      $alias = sprintf q[$INC[%d]], $inc_no;
      $inc = $candidate_inc;
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
  return $self->get_path($alias) if $alias eq $self->get_display($alias);
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

__END__

=pod

=encoding UTF-8

=head1 NAME

Module::Path::Simplify - Simplify absolute paths for pretty-printing.

=head1 VERSION

version 0.001000

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

=head1 METHODS

=head2 C<new>

Create a C<simplifier> object.

=head2 C<simplify>

Return a simplified version of a path, or the path itself
if there are no simplifications available

  print $simpl->simplify( $INC{'Test/More.pm'} )

=head2 C<aliases>

Returns the internal alias tracking object.

=head2 C<pp_aliases>

Return a string detailing the used simplification aliases
and where they map to. ( And possibly their internal identifier )

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
