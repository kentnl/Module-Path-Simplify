use strict;
use warnings;

use Test::More;

# ABSTRACT: Test basic functionality

use Module::Path::Simplify;

my $simplifier = Module::Path::Simplify->new();
{
  my $short = $simplifier->simplify( $INC{'Module/Path/Simplify.pm'} );
  isnt( $short, $INC{'Module/Path/Simplify.pm'}, 'Resolved path is simplified relative to inc' );
  note $short;
}
{
  my $short = $simplifier->simplify( $INC{'Test/More.pm'} );
  isnt( $short, $INC{'Test/More.pm'}, 'Resolved path is simplified relative to inc' );
  note $short;
}

note $simplifier->pp_aliases;

done_testing;

