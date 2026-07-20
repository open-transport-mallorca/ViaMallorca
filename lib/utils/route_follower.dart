import 'dart:math';

import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

/// How far a fix may sit from the drawn route and still be considered "on" it.
///
/// GPS noise and the coarse KMZ geometry account for a few tens of metres; past
/// this the bus is somewhere the route does not go.
const double _maxSnapMeters = 60;

/// How much longer than the direct line the along-route path may be.
///
/// Buses take unmapped detours, and the drawn route is a concatenation of every
/// KMZ line string, so consecutive vertices are not always connected on the
/// ground. Either way, a route path far longer than the straight line between
/// two fixes is not the way the bus actually went.
const double _maxDetourFactor = 2.5;

/// Absolute slack for the detour test, so short hops between nearby fixes are
/// not rejected merely because the route wiggles.
const double _detourSlackMeters = 120;

/// A point projected onto a polyline.
class _Projection {
  const _Projection({
    required this.segment,
    required this.t,
    required this.point,
    required this.distance,
  });

  /// Index of the vertex that starts the segment the point fell on.
  final int segment;

  /// How far along that segment the projection sits, from 0 to 1.
  final double t;

  final LatLng point;

  /// Metres between the original point and its projection.
  final double distance;
}

/// Local metres-per-degree, accurate enough over a single segment.
const double _metersPerDegLat = 110540.0;
double _metersPerDegLon(double lat) => 111320.0 * cos(lat * pi / 180);

_Projection _projectOnSegment(LatLng p, LatLng a, LatLng b, int segment) {
  final mx = _metersPerDegLon(a.latitude);
  final bx = (b.longitude - a.longitude) * mx;
  final by = (b.latitude - a.latitude) * _metersPerDegLat;
  final px = (p.longitude - a.longitude) * mx;
  final py = (p.latitude - a.latitude) * _metersPerDegLat;

  final lengthSquared = bx * bx + by * by;
  final t = lengthSquared == 0
      ? 0.0
      : ((px * bx + py * by) / lengthSquared).clamp(0.0, 1.0);

  final point = LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );
  final dx = px - bx * t;
  final dy = py - by * t;

  return _Projection(
    segment: segment,
    t: t,
    point: point,
    distance: sqrt(dx * dx + dy * dy),
  );
}

_Projection? _project(List<LatLng> route, LatLng point) {
  _Projection? best;
  for (int i = 0; i < route.length - 1; i++) {
    final candidate = _projectOnSegment(point, route[i], route[i + 1], i);
    if (best == null || candidate.distance < best.distance) {
      best = candidate;
    }
  }
  return best;
}

double _pathLength(List<LatLng> points) {
  double total = 0;
  for (int i = 0; i < points.length - 1; i++) {
    total += _distance.as(LengthUnit.Meter, points[i], points[i + 1]);
  }
  return total;
}

/// The stretch of [route] the bus most likely covered going from [from] to
/// [to], or null when the route cannot explain that movement.
///
/// Returns null — meaning the caller should fall back to a straight line —
/// when either point is more than [_maxSnapMeters] off the route, when the
/// movement runs backwards along it, or when the route between the two points
/// is implausibly long compared to the direct distance. That last case is what
/// catches buses taking a bypass the drawn route knows nothing about: the
/// projections land on whatever part of the route happens to be nearest, and
/// the resulting detour gives the mismatch away.
List<LatLng>? pathBetween(List<LatLng> route, LatLng from, LatLng to) {
  if (route.length < 2) return null;

  final start = _project(route, from);
  final end = _project(route, to);
  if (start == null || end == null) return null;
  if (start.distance > _maxSnapMeters || end.distance > _maxSnapMeters) {
    return null;
  }

  // Moving backwards along the route means we snapped to the wrong pass of a
  // loop, or the bus is not on this direction of the line at all.
  if (end.segment < start.segment ||
      (end.segment == start.segment && end.t < start.t)) {
    return null;
  }

  final points = <LatLng>[from, start.point];
  for (int i = start.segment + 1; i <= end.segment; i++) {
    points.add(route[i]);
  }
  points
    ..add(end.point)
    ..add(to);

  final along = _pathLength(points);
  final direct = _distance.as(LengthUnit.Meter, from, to);
  if (along > direct * _maxDetourFactor + _detourSlackMeters) return null;

  return points;
}

/// A polyline that can be sampled by fraction of its total length, so a marker
/// moves at a constant speed rather than jumping vertex to vertex.
class InterpolatedPath {
  InterpolatedPath(this.points)
      : assert(points.isNotEmpty),
        _cumulative = List<double>.filled(points.length, 0) {
    for (int i = 1; i < points.length; i++) {
      _cumulative[i] = _cumulative[i - 1] +
          _distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
  }

  final List<LatLng> points;
  final List<double> _cumulative;

  double get length => _cumulative.last;

  /// The position at [t] (0 to 1) of the way along the path.
  LatLng at(double t) {
    if (points.length == 1 || length == 0) return points.last;
    final target = (t.clamp(0.0, 1.0)) * length;

    // The path is a handful of points, so a linear scan costs nothing.
    for (int i = 1; i < points.length; i++) {
      if (_cumulative[i] < target) continue;
      final segmentLength = _cumulative[i] - _cumulative[i - 1];
      if (segmentLength == 0) return points[i];
      final local = (target - _cumulative[i - 1]) / segmentLength;
      final a = points[i - 1];
      final b = points[i];
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * local,
        a.longitude + (b.longitude - a.longitude) * local,
      );
    }
    return points.last;
  }
}

/// The stretch of route covered so far and the stretch still to come.
typedef RouteSplit = ({List<LatLng> travelled, List<LatLng> remaining});

/// A drawn route that can report how far along it a position sits, and be cut
/// at that point so the two halves can be styled differently.
///
/// Building one walks the whole route, so hold onto it rather than rebuilding
/// per frame — routes run to a couple of thousand vertices.
class RouteProgress extends InterpolatedPath {
  RouteProgress(super.points);

  /// Metres along the route at [point], or null when it is too far off the
  /// route for the answer to mean anything.
  double? distanceAt(LatLng point) {
    final projection = _project(points, point);
    if (projection == null || projection.distance > _maxSnapMeters) return null;

    final start = _cumulative[projection.segment];
    final end = _cumulative[projection.segment + 1];
    return start + (end - start) * projection.t;
  }

  /// Cuts the route at [distance] metres along it.
  ///
  /// Both halves share the cut point, so they meet exactly rather than leaving
  /// a gap. Either half may be shorter than two points when the bus sits at one
  /// end of the route; callers should skip drawing those.
  RouteSplit split(double distance) {
    if (distance <= 0) return (travelled: const [], remaining: points);
    if (distance >= length) return (travelled: points, remaining: const []);

    for (int i = 1; i < points.length; i++) {
      if (_cumulative[i] < distance) continue;

      final segment = _cumulative[i] - _cumulative[i - 1];
      final local =
          segment == 0 ? 0.0 : (distance - _cumulative[i - 1]) / segment;
      final a = points[i - 1];
      final b = points[i];
      final cut = LatLng(
        a.latitude + (b.latitude - a.latitude) * local,
        a.longitude + (b.longitude - a.longitude) * local,
      );

      return (
        travelled: [...points.sublist(0, i), cut],
        remaining: [cut, ...points.sublist(i)],
      );
    }

    return (travelled: points, remaining: const []);
  }
}
