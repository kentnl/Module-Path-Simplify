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

sub _add_non_inc_paths {
  my ( $self, $spec ) = @_;
  $self->{_non_inc_paths} = {} unless exists $self->{_non_inc_paths};
  for my $alias ( keys %{$spec} ) {
    $self->{_non_inc_paths}->{$alias} = $spec->{$alias};
  }
}

sub _non_inc_paths {
  my ($self) = @_;
  return $self->{_non_inc_paths} if exists $self->{_non_inc_paths};
  $self->_add_non_inc_paths( $self->_config_paths );
  $self->_add_non_inc_paths( $self->_relative_paths );
  $self->_add_non_inc_paths( $self->_home_paths );
  return $self->{_non_inc_paths};
}

sub _non_inc_order {
  my ($self) = @_;
  return $self->{_non_inc_order} if exists $self->{_non_inc_order};
  $self->{_non_inc_order} = [

  ];
}

sub _set_alias_display {
  my ( $self, @args ) = @_;
  my (%opts) = 'HASH' eq ref $args[0] ? %{ $args[0] } : @args;
  my $config = $self->_non_inc_paths;    # Initializer.
  for my $alias ( sort keys %opts ) {
    if ( exists $config->{$alias} ) {
      $config->{$alias}->{display} = $opts{$alias};
    }
  }
  return;
}

sub _set_alias_display_riba {
  my ($self) = @_;
  $self->_set_alias_display(
    'env_home'        => 'HOME',
    'env_userprofile' => 'HOME',
    'file_homedir'    => 'HOME',
    '~'               => 'HOME',
    archlib           => 'PA',
    blib_arch         => 'BLA',
    blib_lib          => 'BLL',
    inc               => 'INC',
    lib               => 'LIB',
    prefix            => 'PP',
    privlib           => 'PL',
    sitearch          => 'SA',
    sitelib           => 'SL',
    sitelib_stem      => 'SS',
    siteprefix        => 'SP',
    t                 => 'T',
    vendorarch        => 'VA',
    vendorlib         => 'VL',
    vendorlib_stem    => 'VS',
    vendorprefix      => 'VP',
  );
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

sub _config_paths {
  require Config;
  my @config_keys = qw(
    sitearch
    sitelib
    sitelib_stem
    siteprefix
    vendorarch
    vendorlib
    vendorlib_stem
    archlib
    privlib
    prefix
  );
  my $out = {};

  for my $config_key (@config_keys) {
    $out->{$config_key} = {
      display => $config_key,
      path    => $Config::Config{$config_key},
    };
  }
  return $out;
}

sub _relative_paths {
  return {
    'blib_arch' => { display => 'blib/arch', path => './blib/arch' },
    'blib_lib'  => { display => 'blib/lib',  path => './blib/lib' },
    'inc'       => { display => 'inc',       path => './inc' },
    'lib'       => { display => 'lib',       path => './lib' },
    't'         => { display => 't',         path => './t' },
    'cwd'       => { display => '.',         path => '.' },
  };
}

sub _home_paths {
  my $hash = {};
  if ( eval sprintf 'require %1$s; %1$s->my_home; 1', 'File::HomeDir' ) {
    $hash->{file_homedir} = { display => '~', path => File::HomeDir->my_home };
  }
  elsif ( $ENV{USERPROFILE} ) {
    $hash->{env_userprofile} = { display => '~', path => $ENV{USERPROFILE} };
  }
  elsif ( $ENV{HOME} ) {
    $hash->{env_home} = { display => '~', path => $ENV{HOME} };
  }
  else {
    $hash->{'~'} = { display => '~', path => glob('~') };
  }
  return $hash;
}

1;
