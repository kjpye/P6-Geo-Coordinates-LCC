use v6;

# Loosely based on Geo::Coordinates::UTM.

module Geo::Coordinates::LCC {

  use Geo::Coordinates::Ellipsoid;

  constant \deg2rad =   π / 180;
  constant \rad2deg = 180 /   π;
   
  class Projection {
    has $.name;
    has $.lat1;
    has $.lat2;
    has $.lat0;
    has $.long0;
    has $.false-easting;
    has $.false-northing;

    method create($name, $lat1, $lat2, $lat0, $long0, $false-easting, $false-northing) {
      Projection.new(:$name, :$lat1, :$lat2, :$lat0, :$long0, :$false-easting, :$false-northing);
    }
  }

  my @Projection;
  my %Projection;
   
  BEGIN {  # Initialize this before other modules get a chance

    @Projection = (
                    Projection.create('vicgrid94', 36 *deg2rad, 38 *deg2rad, 37 *deg2rad, 145 *deg2rad, 2500000, 2500000),
                  );
    for @Projection -> $pr {
        %Projection{$pr.name} = $pr;
        %Projection{cleanup-name $pr.name} = $pr;
    }

  }

  # Returns all pre-defined projection names, sorted alphabetically
  sub projection-names() is export {
      @Projection ==> map { .name };
  }

  # Returns "official" name, ...
#FIX
  # Examples:   my($name, $r, $sqecc) = projection-info 'wgs84';
  #             my($name, $r, $sqecc) = projection-info 'WGS 84';
  #             my($name, $r, $sqecc) = projection-info 'WGS-84';
  #             my($name, $r, $sqecc) = projection-info 'WGS-84 (new specs)';
  #             my($name, $r, $sqecc) = projection-info 22;

  sub projection-info(Str $id) is export {
     %Ellipsoid{$id} // %Ellipsoid{cleanup-name $id};
  }

  my $lastellips = '';
  my $name;
  my $eccentricity;
  my $radius;
  my ($k1, $k2, $k3, $k4);

  set-ellipse 'WGS-84'; # As good a default as any

  proto sub set-projection(|) is export { * }

  my $φ1;
  my $φ2;
  my $φ0;
  my $λ0;
  my $false-easting;
  my $false-northing;

  multi sub set-projection(Str $name) is export {
    my $pr = projection-info($name);
    fail "Unknown projection $name" unless $pr.defined;
    $φ0 = $pr.lat0;
    $φ1 = $pr.lat1;
    $φ2 = $pr.lat2;
    $λ0 = $pr.long0;
    $false-easting = $pr.false-easting;
    $false-northing = $pr.false-northing;
  }

  multi sub set-projection($new-φ1, $new-φ2, $new-φ0, $new-λ0, $new-false-easting, $new-false-northing) is export {
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

  # Expects LCC Easting, LCC Northing (uses previously set projection)
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
    my \φ  = χ + (e²/2 + 5 × e**4 /  24 +      e**6 /  12 +  13 × e**8 /    360) × sin(2 × χ)
               + (       7 × e**4 /  48 + 29 × e**6 / 240 + 811 × e**8 / 115200) × sin(4 × χ)
               + (                         7 × e**6 / 120 +  81 × e**8 /   1120) × sin(6 × χ)
               + (                                         4279 × e**8 / 161280) × sin(8 × χ);

    my \θ  = atan(x/(ρ0 - y));
    my \λ  = θ/n + λ0;
    (φ, λ);
  }
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

=head2 Lambert Conformal Conic Projection

The equations used in this module are from "Map Projections - A Working Manual" by John P. Snyder. (https://pubs.usgs.gov/pp/1395/report.pdf)

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
