use v6;

# Loosely based on Geo::Coordinates::LCC.

module Geo::Coordinates::LCC {

   constant \deg2rad =   π / 180;
   constant \rad2deg = 180 /   π;
   
   # remove all markup from an ellipsoid name, to increase the chance
   # that a match is found.
   sub cleanup-name(Str $copy is copy) {
       $copy .= lc;
       $copy ~~ s:g/ \( <-[)]>* \) //;   # remove text between parentheses
       $copy ~~ s:g/ <[\s-]> //;         # no blanks or dashes
       $copy;
   }
   
   # Ellipsoid array (name,equatorial radius,square of eccentricity)
   # Same data also as hash with key eq name (in variations)
   
  class Ellipsoid {
    has $.name;
    has $.radius;
    has $.eccentricity;

    method create($name, $radius, $eccentricity) {
      Ellipsoid.new(name => $name, radius => $radius.Num, eccentricity => $eccentricity.Num);
    }

    submethod TWEAK() {
    }
  }

  my (@Ellipsoid, %Ellipsoid);
   
  BEGIN {  # Initialize this before other modules get a chance
    @Ellipsoid = (
      Ellipsoid.create("Airy",                                6377563,     0.006670540),
      Ellipsoid.create("Australian National",                 6378160,     0.006694542),
      Ellipsoid.create("Bessel 1841",                         6377397,     0.006674372),
      Ellipsoid.create("Bessel 1841 Nambia",                  6377484,     0.006674372),
      Ellipsoid.create("Clarke 1866",                         6378206,     0.006768658),
      Ellipsoid.create("Clarke 1880",                         6378249,     0.006803511),
      Ellipsoid.create("Everest 1830 India",                  6377276,     0.006637847),
      Ellipsoid.create("Fischer 1960 Mercury",                6378166,     0.006693422),
      Ellipsoid.create("Fischer 1968",                        6378150,     0.006693422),
      Ellipsoid.create("GRS 1967",                            6378160,     0.006694605),
      Ellipsoid.create("GRS 1980",                            6378137,     0.006694380),
      Ellipsoid.create("Helmert 1906",                        6378200,     0.006693422),
      Ellipsoid.create("Hough",                               6378270,     0.006722670),
      Ellipsoid.create("International",                       6378388,     0.006722670),
      Ellipsoid.create("Krassovsky",                          6378245,     0.006693422),
      Ellipsoid.create("Modified Airy",                       6377340,     0.006670540),
      Ellipsoid.create("Modified Everest",                    6377304,     0.006637847),
      Ellipsoid.create("Modified Fischer 1960",               6378155,     0.006693422),
      Ellipsoid.create("South American 1969",                 6378160,     0.006694542),
      Ellipsoid.create("WGS 60",                              6378165,     0.006693422),
      Ellipsoid.create("WGS 66",                              6378145,     0.006694542),
      Ellipsoid.create("WGS-72",                              6378135,     0.006694318),
      Ellipsoid.create("WGS-84",                              6378137,     0.00669438 ),
      Ellipsoid.create("Everest 1830 Malaysia",               6377299,     0.006637847),
      Ellipsoid.create("Everest 1956 India",                  6377301,     0.006637847),
      Ellipsoid.create("Everest 1964 Malaysia and Singapore", 6377304,     0.006637847),
      Ellipsoid.create("Everest 1969 Malaysia",               6377296,     0.006637847),
      Ellipsoid.create("Everest Pakistan",                    6377296,     0.006637534),
      Ellipsoid.create("Indonesian 1974",                     6378160,     0.006694609),
      Ellipsoid.create("Arc 1950",                            6378249.145, 0.006803481),
      Ellipsoid.create("NAD 27",                              6378206.4,   0.006768658),
      Ellipsoid.create("NAD 83",                              6378137,     0.006694384),
    );

  # calc ecc  as  
  # a = semi major axis
  # b = semi minor axis
  # e^2 = (a^2-b^2)/a^2	
  # For clarke 1880 (Arc1950) a=6378249.145 b=6356514.966398753
  # e^2 (40682062155693.23 - 40405282518051.34) / 40682062155693.23
  # e^2 = 0.0068034810178165


    for @Ellipsoid -> $el {
        %Ellipsoid{$el.name} = $el;
        %Ellipsoid{cleanup-name $el.name} = $el;
    }
  }

  # Returns all pre-defined ellipsoid names, sorted alphabetically
  sub ellipsoid-names() is export {
      @Ellipsoid ==> map { .name };
  }

  # Returns "official" name, equator radius and square eccentricity
  # The specified name can be numeric (for compatibility reasons) or
  # a more-or-less exact name
  # Examples:   my($name, $r, $sqecc) = ellipsoid-info 'wgs84';
  #             my($name, $r, $sqecc) = ellipsoid-info 'WGS 84';
  #             my($name, $r, $sqecc) = ellipsoid-info 'WGS-84';
  #             my($name, $r, $sqecc) = ellipsoid-info 'WGS-84 (new specs)';
  #             my($name, $r, $sqecc) = ellipsoid-info 22;

  sub ellipsoid-info(Str $id) is export {
     %Ellipsoid{$id} // %Ellipsoid{cleanup-name $id};
  }

  my $lastellips = '';
  my $name;
  my $eccentricity;
  my $radius;
  my ($k1, $k2, $k3, $k4);

  proto sub set-ellipse(|) is export { * }

  multi sub set-ellipse(Str $name) {
    my $el = ellipsoid-info($name);
    fail "Unknown ellipsoid $name" unless $el.defined;
    $eccentricity = $el.eccentricity;
    $radius       = $el.radius;
  }

  multi sub set-ellipse($new-radius, $new-eccentricity) {
    $radius = $new-radius;
    $eccentricity = $new-eccentricity;
  }

  set-ellipse 'WGS-84'; # As good a default as any

  proto sub set-projection(|) is export { * }

  multi sub set-projection(Str $name) is export {
  }

  my $R;
  my $φ1;
  my $φ2;
  my $φ0;
  my $λ0;
  my $false-easting;
  my $false-northing;

  multi sub set-projection($new-R, $new-φ1, $new-φ2, $new-φ0, $new-λ0, $new-false-easting, $new-false-northing) is export {
    $R              = $new-R;
    $φ1             = $new-φ1 * deg2rad;
    $φ2             = $new-φ2 * deg2rad;
    $φ0             = $new-φ0 * deg2rad;
    $λ0             = $new-λ0 * deg2rad;
    $false-easting  = $new-false-easting;
    $false-northing = $new-false-northing;
  }

  sub prefix:<ln>($a) { log $a; }

   # Expects Ellipsoid Number or name, Latitude, Longitude 
   # (Latitude and Longitude in decimal degrees)
   # Returns LCC Zone, LCC Easting, LCC Northing

   sub latlon-to-lcc(Real $φ, Real $λ) is export {
       fail "Longitude value ($λ) invalid."
           unless -180 <= $λ <= 180;
       fail "Latitude value ($φ) invalid."
           unless -90 <= $φ <= 90;
     my \a  := $radius;
     my \e  := $eccentricity;
     my \λ   = $λ * deg2rad;
     my \λ0 := $λ0;
     my \φ   = $φ * deg2rad;
     my \φ0 := $φ0;
     my \φ1 := $φ1;
     my \φ2 := $φ2;

     my \t  = tan(π/4 - φ /2)/((1 - e × sin φ )/(1 + e × sin φ )) ** ( e / 2);
     my \t0 = tan(π/4 - φ0/2)/((1 - e × sin φ0)/(1 + e × sin φ0)) ** ( e / 2);
     my \t1 = tan(π/4 - φ1/2)/((1 - e × sin φ1)/(1 + e × sin φ1)) ** ( e / 2);
     my \t2 = tan(π/4 - φ2/2)/((1 - e × sin φ2)/(1 + e × sin φ2)) ** ( e / 2);

     my \m  = cos(φ)/sqrt(1 - e×e × (sin φ ) ** 2);
     my \m1 = cos(φ1)/sqrt(1 - (e × (sin φ1)) ** 2);
     my \m2 = cos(φ2)/(1 - e×e × (sin φ2) ** 2) ** 0.5;

     my \n  = (ln m1 - ln m2)/(ln t1 - ln t2);
     my \F  = m1 / ( n × t1 ** n);
     my \ρ0 = a × F × t0 ** n;
     my \θ  = n × (λ - λ0);
     my \ρ  = a × F × t ** n;
     my \k  = m1 × t ** n / (m × t1 ** n);
     my \x  = ρ × sin θ;
     my \y  = ρ0 - ρ × cos θ;
     (x + $false-easting, y + $false-northing);
   }

  # Expects Ellipsoid Number or name, LCC zone, LCC Easting, LCC Northing
  # Returns Latitude, Longitude
  # (Latitude and Longitude in decimal degrees, LCC Zone e.g. 23S)

  sub lcc-to-latlon(Real $x, Real $y) is export {
#    my ($name, $radius, $eccentricity) = |ellipsoid-info $ellips
#      or fail "Ellipsoid value ($ellips) invalid.";
    my \e  := $eccentricity;
    my \x  := $x;
    my \y  := $y;
    my \a  := $radius;
    my \λ0 := $λ0;
    my \φ0 := $φ0;
    my \φ1 := $φ1;
    my \φ2 := $φ2;

    my \m1 = cos(φ1)/sqrt(1 - e×e × (sin φ1)²);
    my \m2 = cos(φ2)/sqrt(1 - e×e × (sin φ2)²);
    my \t0 = tan(π/4 - φ0/2)/((1 - e × sin φ0)/(1 + e × sin φ0)) ** ( e / 2);
    my \t1 = tan(π/4 - φ1/2)/((1 - e × sin φ1)/(1 + e × sin φ1)) ** ( e / 2);
    my \t2 = tan(π/4 - φ2/2)/((1 - e × sin φ2)/(1 + e × sin φ2)) ** ( e / 2);
    my \n  = (ln m1 - ln m2)/(ln t1 - ln t2);
    my \F  = m1 / ( n × t1 ** n);
    my \ρ0 = a × F × t0 ** n;
    my \ρ  = sign(n) × sqrt(x² + (ρ0 - y)**2);
    my \t  = (ρ / (a * F)) ** (1/n);
    my \χ  = π/2 - 2 × atan t;
say 'χ  ', χ;
    my \φ  = χ + (e²/2 + 5 × e**4 /  24 +      e**6 /  12 +  13 × e**8 /    360) × sin(2 × χ)
               + (       7 × e**4 /  48 + 29 × e**6 / 240 + 811 × e**8 / 115200) × sin(4 × χ)
               + (                         7 × e**6 / 120 +  81 × e**8 /   1120) × sin(6 × χ)
               + (                                         4279 × e**8 / 161280) × sin(8 × χ);

    my \θ  = atan(x/(ρ0 - y));
    my \λ  = θ/n + λ0;
    (φ, λ);
  }

set-ellipse(6378206.4, sqrt(0.00676866));
set-projection(6378206.4, 33, 45, 23, -96, 0, 0);
my ($x, $y) = |latlon-to-lcc(-35, -75);
dd latlon-to-lcc(35.0, -75.0);

#set-ellipse('WGS-84');
#set-projection(0, -38, -36, -37, 145, 2500000, 2500000);
my ($long, $lat) = lcc-to-latlon($x, $y);
say $long*rad2deg, ' ', $lat*rad2deg;
} # end module

=begin pod
=head1 NAME

Geo::Coordinates::LCC - Perl extension for Latitude Longitude conversions.

=head1 SYNOPSIS

use Geo::Coordinates::LCC;

my ($zone,$easting,$northing)=|latlon-to-utm($ellipsoid,$latitude,$longitude);

my ($latitude,$longitude)=|utm-to-latlon($ellipsoid,$zone,$easting,$northing);

my ($zone,$easting,$northing)=|mgrs-to-utm($mgrs);

my ($latitude,$longitude)=|mgrs-to-latlon($ellipsoid,$mgrs);

my ($mgrs)=|utm-to-mgrs($zone,$easting,$northing);

my ($mgrs)=|latlon-to-mgrs($ellipsoid,$latitude,$longitude);

my @ellipsoids=ellipsoid-names;

my($name, $r, $sqecc) = |ellipsoid-info 'WGS-84';

=head1 DESCRIPTION

This module will translate latitude longitude coordinates to Universal Transverse Mercator(LCC) coordinates and vice versa.

=head2 Mercator Projection

The Mercator projection was first invented to help mariners. They needed
to be able to draw a straight line on a map and follow that bearing to
arrive at a destination. In order to do this,
Mercator invented a projection which preserved angle, by projecting the
earth's surface onto a cylinder, sharing the same axis as the earth
itself. This caused all Latitude and Longitude lines to be straight and
to intersect at a 90 degree angle, but the downside was that the scale of
the map increased as you moved away from the equator so that the lines of
longitude were parallel.

Because the scale varies, areas near the poles appear much larger on the
map than a similar sized object near the equator. The Mercator Projection
is useless near the poles since the scale becomes infinite.

=head2 Transverse Mercator Projection

A Transverse Mercator projection takes the cylinder and turns it on its
side. Now the cylinder's axis passes through the equator, and it can be
rotated to line up with the area of interest. Many countries use
Transverse Mercator for their grid systems. The disadvantage is that now
neither the lines of latitude or longitude (apart from the central
meridian) are straight.

=head2 Universal Transverse Mercator

The Universal Transverse Mercator(LCC) system sets up a universal world
wide system for mapping. The Transverse Mercator projection is used,
with the cylinder in 60 positions. This creates 60 zones around the
world. Positions are measured using Eastings and Northings, measured in
meters, instead of Latitude and Longitude. Eastings start at 500,000 on
the centre line of each zone. In the Northern Hemisphere, Northings are
zero at the equator and increase northward. In the Southern Hemisphere,
Northings start at 10 million at the equator, and decrease southward.
You must know which hemisphere and zone you are in to interpret your
location globally. Distortion of scale, distance and area increase away
from the central meridian.

LCC projection is used to define horizontal positions world-wide by
dividing the surface of the Earth into 6 degree zones, each mapped by
the Transverse Mercator projection with a central meridian in the center
of the zone. LCC zone numbers designate 6 degree longitudinal strips
extending from 80 degrees South latitude to 84 degrees North latitude.
LCC zone characters designate 8 degree zones extending north and south
from the equator. Eastings are measured from the central meridian (with
a 500 km false easting to insure positive coordinates). Northings are
measured from the equator (with a 10,000 km false northing for positions
south of the equator).

LCC is applied separately to the Northern and Southern Hemisphere, thus
within a single LCC zone, a single X / Y pair of values will occur in
both the Northern and Southern Hemisphere. To eliminate this confusion,
and to speed location of points, a LCC zone is sometimes subdivided into
20 zones of Latitude. These grids can be further subdivided into 100,000
meter grid squares with double-letter designations. This subdivision by
Latitude and further division into grid squares is generally referred to
as the Military Grid Reference System (MGRS). The unit of measurement of
LCC is always meters and the zones are numbered from 1 to 60 eastward,
beginning at the 180th meridian. The scale distortion in a north-south
direction parallel to the central meridian (CM) is constant However, the
scale distortion increases either direction away from the CM. To
equalize the distortion of the map across the LCC zone, a scale factor
of 0.9996 is applied to all distance measurements within the zone. The
distortion at the zone boundary, 3 degrees away from the CM is
approximately 1%.

=head2 Datums and Ellipsoids

Unlike local surveys, which treat the Earth as a plane, the precise
determination of the latitude and longitude of points over a broad area
must take into account the actual shape of the Earth. To achieve the
precision necessary for accurate location, the Earth cannot be assumed
to be a sphere. Rather, the Earth's shape more closely approximates an
ellipsoid (oblate spheroid): flattened at the poles and bulging at the
Equator. Thus the Earth's shape, when cut through its polar axis,
approximates an ellipse. A "Datum" is a standard representation of shape
and offset for coordinates, which includes an ellipsoid and an origin.
You must consider the Datum when working with geospatial data, since
data with two different Datum will not line up. The difference can be as
much as a kilometer!

=head1 EXAMPLES

A description of the available ellipsoids and sample usage of the conversion routines follows

=head2 Ellipsoids

The Ellipsoids available are as follows:

=item 1 Airy

=item 2 Australian National

=item 3 Bessel 1841

=item 4 Bessel 1841 (Nambia)

=item 5 Clarke 1866

=item 6 Clarke 1880

=item 7 Everest 1830 (India)

=item 8 Fischer 1960 (Mercury)

=item 9 Fischer 1968

=item 10 GRS 1967

=item 11 GRS 1980

=item 12 Helmert 1906

=item 13 Hough

=item 14 International

=item 15 Krassovsky

=item 16 Modified Airy

=item 17 Modified Everest

=item 18 Modified Fischer 1960

=item 19 South American 1969

=item 20 WGS 60

=item 21 WGS 66

=item 22 WGS-72

=item 23 WGS-84

=item 24 Everest 1830 (Malaysia)

=item 25 Everest 1956 (India)

=item 26 Everest 1964 (Malaysia and Singapore)

=item 27 Everest 1969 (Malaysia)

=item 28 Everest (Pakistan)

=item 29 Indonesian 1974

=item 30 Arc 1950

=item 31 NAD 27

=item 32 NAD 83

=head2 ellipsoid-names

The ellipsoids can be accessed using C<ellipsoid-names>. To store these into an array you could use 

     my @names = ellipsoid-names;

=head2 ellipsoid-info

Ellipsoids may be called either by name, or number. To return the ellipsoid information,
( "official" name, equator radius and square eccentricity)
you can use C<ellipsoid-info> and specify a name. The specified name can be numeric
(for compatibility reasons) or a more-or-less exact name.
Any text between parentheses will be ignored.

     my($name, $r, $sqecc) = |ellipsoid-info 'wgs84';
     my($name, $r, $sqecc) = |ellipsoid-info 'WGS 84';
     my($name, $r, $sqecc) = |ellipsoid-info 'WGS-84';
     my($name, $r, $sqecc) = |ellipsoid-info 'WGS-84 (new specs)';
     my($name, $r, $sqecc) = |ellipsoid-info 23;

=head2 latlon-to-utm

Latitude values in the southern hemisphere should be supplied as negative values
(e.g. 30 deg South will be -30). Similarly Longitude values West of the meridian
should also be supplied as negative values. Both latitude and longitude should
not be entered as deg,min,sec but as their decimal equivalent,
e.g. 30 deg 12 min 22.432 sec should be entered as 30.2062311

The ellipsoid value should correspond to one of the numbers above,
e.g. to use WGS-84, the ellipsoid value should be 23

For latitude  57deg 49min 59.000sec North
    longitude 02deg 47min 20.226sec West

using Clarke 1866 (Ellipsoid 5)

     ($zone,$east,$north)=|latlon-to-utm('clarke 1866',57.803055556,-2.788951667)

returns 

     $zone  = 30V
     $east  = 512543.777159849
     $north = 6406592.20049111

On occasions, it is necessary to map a pair of (latitude, longitude)
coordinates to a predefined zone. This is done by providing a value for the optional named parameter zone as follows:

     ($zone, $east, $north)=|latlon-to-utm('international', :zone($zone-number),
                                          $latitude, $longitude)

For instance, Spain territory goes over zones 29, 30 and 31 but
sometimes it is convenient to use the projection corresponding to zone
30 for all the country.

Santiago de Compostela is at 42deg 52min 57.06sec North, 8deg 32min 28.70sec West

    ($zone, $east, $norh)=|latlon-to-utm('international',  42.882517, -8.541306)

returns

     $zone = 29T
     $east = 537460.331
     $north = 4747955.991

but forcing the conversion to zone 30:

    ($zone, $east, $norh)=|latlon-to-utm('international', :zone(30),
                                         42.882517, -8.541306)

returns

    $zone = 30T
    $east = 47404.442
    $north = 4762771.704

=head2 utm-to-latlon

Reversing the above example,

     ($latitude,$longitude)=|utm-to-latlon(5,'30V',512543.777159849,6406592.20049111)

returns

     $latitude  = 57.8030555601332
     $longitude = -2.7889516669741

     which equates to

     latitude  57deg 49min 59.000sec North
     longitude 02deg 47min 20.226sec West


=head2 latlon-to-mgrs

Latitude values in the southern hemisphere should be supplied as negative values
(e.g. 30 deg South will be -30). Similarly Longitude values West of the meridian
should also be supplied as negative values. Both latitude and longitude should
not be entered as deg,min,sec but as their decimal equivalent,
e.g. 30 deg 12 min 22.432 sec should be entered as 30.2062311

The ellipsoid value should correspond to one of the numbers above, e.g. to use WGS-84, the ellipsoid value should be 23

For latitude  57deg 49min 59.000sec North
    longitude 02deg 47min 20.226sec West

using WGS84 (Ellipsoid 23)

     ($mgrs)=|latlon-to-mgrs(23,57.8030590197684,-2.788956799)

returns 

     $mgrs  = 30VWK1254306804

=head2 mgrs-to-latlon

Reversing the above example,

     ($latitude,$longitude)=|mgrs-to-latlon(23,'30VWK1254306804')

returns

     $latitude  = 57.8030590197684
     $longitude = -2.788956799645

=head2 mgrs-to-utm

    Similarly it is possible to convert MGRS directly to LCC

        ($zone,$easting,$northing)=|mgrs-to-utm('30VWK1254306804')

    returns

        $zone = 30V
        $easting = 512543
        $northing = 6406804

=head2 utm-to-mgrs

    and the inverse converting from LCC yo MGRS is done as follows

       ($mgrs)=|utm-to-mgrs('30V',512543,6406804);

    returns
        $mgrs = 30VWK1254306804

=head1 AUTHOR

Graham Crookham, grahamc@cpan.org

Kevin Pye, kjpye@cpan.org

=head1 THANKS

Thanks go to the following:

Felipe Mendonca Pimenta for helping out with the Southern hemisphere testing.

Michael Slater for discovering the Escape \Q bug.

Mark Overmeer for the ellipsoid-info routines and code review.

Lok Yan for the >72deg. N bug.

Salvador Fandino for the forced zone LCC and additional tests

Matthias Lendholt for modifications to MGRS calculations

Peder Stray for the short MGRS patch



=head1 COPYRIGHT

Copyright (c) 2000,2002,2004,2007,2010,2013 by Graham Crookham.  All rights reserved.

copyright (c) 2018 by Kevin Pye.
    
This package is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.             

=end pod
