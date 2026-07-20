import 'package:mallorca_transit_services/mallorca_transit_services.dart';

/// Whether a stop only lets passengers off, or only lets them on.
enum StopRestriction { dropOffOnly, pickUpOnly }

/// Boarding restrictions by stop id on [line], optionally limited to one [way].
///
/// The flags live on the stops of individual sublines, and the ones the app
/// shows - the visible sublines - are the ones TIB fills in least. Line 401's
/// visible return subline describes 2 stops; seven hidden sublines covering the
/// same direction describe 11 to 14 each, and they are what say that Mare Selva
/// 2 cannot be boarded. So every subline gets a say.
///
/// Pass [way] when the direction is known, as it is for a subline being drawn.
/// Leave it out when it is not - a departure names its line but not its
/// subline - and every direction is consulted instead, which is the more
/// cautious reading.
///
/// A stop entry carrying neither field means "unknown", not "boards normally",
/// and is ignored. A stop is only reported when every subline with an opinion
/// agrees, so a disagreement between sublines never claims a stop cannot be
/// boarded.
Map<int, StopRestriction> stopRestrictions(RouteLine line, {Way? way}) {
  final opinions = <int, Set<StopRestriction?>>{};

  for (final subline in line.sublines ?? const <Subline>[]) {
    if (way != null && subline.way != way) continue;
    for (final stop in subline.stations) {
      if (stop.pickupType == null && stop.dropoffType == null) continue;
      opinions.putIfAbsent(stop.id, () => <StopRestriction?>{}).add(
            stop.isDischargeOnly
                ? StopRestriction.dropOffOnly
                : stop.isPickupOnly
                    ? StopRestriction.pickUpOnly
                    : null,
          );
    }
  }

  final restrictions = <int, StopRestriction>{};
  opinions.forEach((stopId, opinion) {
    if (opinion.length != 1) return;
    final only = opinion.first;
    if (only != null) restrictions[stopId] = only;
  });
  return restrictions;
}
