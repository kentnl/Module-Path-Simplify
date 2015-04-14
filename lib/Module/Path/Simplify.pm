use 5.006;    # our
use strict;
use warnings;

package Module::Path::Simplify;

our $VERSION = '0.001000';

# ABSTRACT: Simplify absolute paths for pretty-printing.

# AUTHORITY

=method C<new>

Create a C<simplifier> object.

Normally, C<new> captures the state of C<@INC> at its creation time.

This can be disabled to use a per-resolution dynamic C<@INC> via

  ->new( inc_dynamic => 1 );

Additionally, C<@INC> can be overridden with a custom list via

  ->new( inc => [ @INC ] );

L<< C<inc_dynamic>|/inc_dynamic >> and L<< C<inc>|/inc >> don't work together, and setting C<inc_dynamic>
will cause C<inc> to be ignored.

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless { ref $args[0] ? %{ $args[0] } : @args }, $class;
  $self->inc unless $self->inc_dynamic;    # Force freezing at new
  return $self;
}

=method C<simplify>

Return a simplified version of a path, or the path itself
if there are no simplifications available

  print $simpl->simplify( $INC{'Test/More.pm'} )

=cut

sub simplify {
  my ( $self, $path ) = @_;

  my $match_path = _abs_unix_path($path);

  my $best_match = $self->_find_in_set( $match_path, $self->_tests_config, $self->_tests_inc );

  return $path unless defined $best_match;

  my $match_target = $best_match->{match_target};

  $self->aliases->set( $match_target->alias, $match_target->alias_path, $match_target->display );
  my $real_display = $self->aliases->get_display( $match_target->alias );
  return sprintf q[%s/%s], $real_display, $best_match->{relative_path};
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

=method C<inc_dynamic>

Returns whether or not this simplifier is using a dynamic C<@INC>.

=cut

sub inc_dynamic {
  my ($self) = @_;
  return $self->{inc_dynamic} if exists $self->{inc_dynamic};
  return;
}

=method C<inc>

Returns the snapshot C<@INC> in use when not using C<inc_dynamic>

=cut

sub inc {
  my ($self) = @_;
  return @{ $self->{inc} } if exists $self->{inc};
  return @{ $self->{inc} ||= [@INC] };
}

sub _tests_config {
  my ($self) = @_;
  return @{ $self->{_tests_config} ||= [ $self->_gen_tests_config ] };
}

sub _gen_tests_config {
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
  require Config;
  ## no critic (Lax::ProhibitComplexMappings::LinesNotStatements)
  return map {
    Module::Path::Simplify::_MatchTarget->new(
      ## no critic (Variables::ProhibitPackageVars)
      alias_path => $Config::Config{ $_->{key} },
      alias      => 'config.' . $_->{key},
      ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
      display => '${' . $_->{display} . '}',
    );
  } @try;
}

sub _gen_tests_user_inc {
  my ( undef, $prefix, $list ) = @_;
  my (@u_inc) = @{ $list || [] };
  ## no critic (Lax::ProhibitComplexMappings::LinesNotStatements)
  return map {
    Module::Path::Simplify::_MatchTarget->new(
      alias_path => $u_inc[$_],
      alias      => $prefix . '[' . $_ . ']',
      display    => $prefix . '[' . $_ . ']',
    );
  } 0 .. $#u_inc;
}

# Cache + saves on first use unless nonfrozen.
sub _tests_inc {
  my ($self) = @_;
  ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
  return @{ $self->{_tests_inc} ||= [ $self->_gen_tests_user_inc( '$INC', [ $self->inc ] ) ] } unless $self->inc_dynamic;
  return $self->_gen_tests_user_inc( '$INC', \@INC );
}

sub _find_in_set {
  my ( undef, $path, @tries ) = @_;
  my ( $shortest, $match_target );
  for my $try (@tries) {
    next unless $try->valid and my $short = $try->matched_suffix($path);
    next if defined $shortest and length $short >= length $shortest;
    $shortest     = $short;
    $match_target = $try;
  }
  return unless defined $shortest;
  return {
    relative_path => $shortest,
    match_target  => $match_target,
  };
}

sub _abs_unix_path {
  my ($path) = @_;
  return q{} unless defined $path;
  require File::Spec;
  return q{} unless -e $path or File::Spec->file_name_is_absolute($path);

  # File::Spec's rel2abs does not resolve symlinks
  # we *need* to look at the filesystem to be sure
  require Cwd;
  my $abs_path = Cwd::abs_path($path);

  return $abs_path unless 'MSWin32' eq $^O and $abs_path;

  my $module = 'Win32.pm';
  require $module;    # Hide from autoprereqs

  ## no critic (Subroutines::ProhibitCallsToUnexportedSubs)
  # sometimes we can get a short/longname mix, normalize everything to longnames
  $abs_path = Win32::GetLongPathName($abs_path);

  # Fixup (native) slashes in Config not matching (unixy) slashes in INC
  $abs_path =~ s{ \\ }{/}sgx;

  return $abs_path;
}

package Module::Path::Simplify::_MatchTarget;

sub new {
  my ( $class, @args ) = @_;
  return bless { ref $args[0] ? @{ $args[0] } : @args }, $class;
}

sub display {
  my ( $self, ) = @_;
  return ( $self->{display} || $self->alias );
}

sub alias {
  my ( $self, ) = @_;
  return $self->{alias};
}

sub alias_path {
  my ( $self, ) = @_;
  return $self->{alias_path};
}

sub alias_unixpath {
  my ( $self, ) = @_;
  return $self->{alias_unixpath} if exists $self->{alias_unixpath};
  ## no critic (Subroutines::ProhibitCallsToUnexportedSubs,Subroutines::ProtectPrivateSubs)
  return ( $self->{alias_unixpath} ||= Module::Path::Simplify::_abs_unix_path( $self->alias_path ) );
}

sub valid {
  my ( $self, ) = @_;
  return unless $self->alias_path;
  return unless $self->alias_unixpath;
  return 1;
}

sub matched_suffix {
  my ( $self, $path ) = @_;
  return if not defined $path or ref $path;
  my $prefix = $self->alias_unixpath;
  $prefix =~ s{ /? \z }{/}gxs;
  if ( $path =~ / \A \Q$prefix\E (.*\z) /sx ) {
    my $short = $1;
    return $short;
  }
  return;
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

