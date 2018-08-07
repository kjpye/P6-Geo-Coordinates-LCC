use v6;
use Test;

plan 3;

# use "../lib";
use Geo::Coordinates::LCC;

ok True, "Module loaded";

my (Str $zone, Real $east, Real $north);

set-ellipse('WGS-84');
set-projection('vicgrid94');
ok ($east,$north)=|latlon-to-lcc(145.833055556,-32.788951667), "latlon-to-lcc available";

ok lcc-to-latlon($east,$north), "lcc-to-latlon available";
