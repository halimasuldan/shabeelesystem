/// Whether a bus document's driver fields refer to the selected driver.
///
/// Older bus records may use the driver document id, auth uid, or temporary
/// current-driver field, so reassignment cleanup must recognize each form.
bool busIsAssignedToDriver(
  Map<String, dynamic> busData, {
  required Set<String> driverIds,
  required String? userId,
}) {
  return driverIds.contains(busData['driverId']) ||
      (userId != null &&
          userId.isNotEmpty &&
          busData['driverUserId'] == userId) ||
      driverIds.contains(busData['currentDriverId']);
}
