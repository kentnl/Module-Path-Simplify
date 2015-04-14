use strict;
use warnings;

use Test::More;

# ABSTRACT: Test the set-display functionality

use Module::Path::Simplify;

my $s = Module::Path::Simplify->new();

my $short = $s->simplify( $INC{'Module/Path/Simplify.pm'} );    # Store name in cache.

cmp_ok( scalar $s->aliases->names, '==', 1, "One entry in cache" );

for my $alias ( $s->aliases->names ) {
  $s->aliases->set_display( $alias, "ROBOTS" );
  like( $s->aliases->get_path_suffixed($alias), qr/ \(\Q$alias\E\)/, "Set display causes suffixes to show up" );
  like( $s->aliases->get_display($alias),       qr/\AROBOTS/,        "Set display causes get_display to change" );
}

like( $short = $s->simplify( $INC{'Module/Path/Simplify.pm'} ), qr{\AROBOTS/}, "Simplified path now has custom alias" );
note $short;

note $s->pp_aliases;

done_testing;

