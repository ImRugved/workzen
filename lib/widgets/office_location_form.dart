import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_snackbar.dart';
import '../models/office_location_model.dart';
import '../providers/organization_provider.dart';
import '../providers/toggle_provider.dart';
import '../providers/value_provider.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';

/// The coordinates picked with "Use my current location", and the GPS accuracy
/// of that reading (null when they are the saved ones).
typedef _Coordinates = ({
  double latitude,
  double longitude,
  double? accuracy,
  double? altitude,
  DateTime? capturedAt,
});

/// Bottom sheet where an admin sets the office: name, optional address and the
/// allowed radius. The admin stands at the office and taps "Use my current
/// location"; the coordinates are saved with the rest and are not typed in.
/// Saving writes organization_details/office_location, which every punch in,
/// punch out and break is checked against.
class OfficeLocationForm extends StatefulWidget {
  final OfficeLocationModel? current;

  const OfficeLocationForm({super.key, this.current});

  static Future<void> show(BuildContext context, OfficeLocationModel? current) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OfficeLocationForm(current: current),
    );
  }

  @override
  State<OfficeLocationForm> createState() => _OfficeLocationFormState();
}

class _OfficeLocationFormState extends State<OfficeLocationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _radius;

  // Scoped state: the GPS fix is being read, and the coordinates chosen so far
  final ToggleProvider _locating = ToggleProvider();
  late final ValueProvider<_Coordinates?> _coordinates;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _name = TextEditingController(text: c?.name ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _radius = TextEditingController(
      text: (c?.radiusMeters ?? OfficeLocationModel.defaultRadius)
          .round()
          .toString(),
    );
    _coordinates = ValueProvider<_Coordinates?>(
      c == null
          ? null
          : (
              latitude: c.latitude,
              longitude: c.longitude,
              accuracy: null,
              altitude: null,
              capturedAt: null,
            ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _radius.dispose();
    _locating.dispose();
    _coordinates.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    _locating.set(true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        ConstantSnackbar.showError(
          title: 'Location services are disabled. Please enable GPS.',
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ConstantSnackbar.showError(
          title: 'Location permission is needed to use your current location.',
        );
        return;
      }

      // "Approximate" location is blurred by kilometres: precise is required
      if (await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced) {
        ConstantSnackbar.showError(
          title: 'Turn on "Precise location" for this app, then try again.',
        );
        await Geolocator.openAppSettings();
        return;
      }

      final captured = await _readBestLocation();
      if (captured == null) {
        ConstantSnackbar.showError(title: 'Failed to get location. Try again.');
        return;
      }
      final accuracy = captured.accuracy ?? 0;
      logDebug(
        'Office location captured: ${captured.latitude}, ${captured.longitude} '
        '(accuracy $accuracy m, altitude ${captured.altitude} m)',
      );
      if (accuracy > _goodAccuracy) {
        ConstantSnackbar.show(
          title:
              'Accuracy is only ±${accuracy.round()} m. Move near a window or '
              'outside and tap again for a better point.',
          backgroundColor: ConstColors.inProgressOrange,
        );
      }

      // Fill the address from the coordinates (needs internet)
      final resolved = await _addressFor(captured.latitude, captured.longitude);
      if (resolved != null) {
        _address.text = resolved;
      } else {
        ConstantSnackbar.show(
          title: 'Address not found. You can type it.',
          backgroundColor: ConstColors.inProgressOrange,
        );
      }
    } catch (e) {
      logDebug('Error getting office location: $e');
      ConstantSnackbar.showError(title: 'Failed to get location. Try again.');
    } finally {
      _locating.set(false);
    }
  }

  // Accuracy (metres) at or under which the point is considered good
  static const double _goodAccuracy = 10;
  // Longest the GPS is read, and the accuracy that ends the reading early
  static const Duration _readTime = Duration(seconds: 12);
  static const double _stopAccuracy = 5;

  // Reads the GPS for up to [_readTime] and combines the readings: each one
  // counts by 1 / accuracy², so precise readings dominate and a drifting one
  // hardly moves the point. The card updates live as the estimate improves.
  // The reported accuracy is the best single reading, not an optimistic guess.
  Future<_Coordinates?> _readBestLocation() async {
    var weightSum = 0.0;
    var latSum = 0.0;
    var lngSum = 0.0;
    double? bestAccuracy;
    double? altitude;
    DateTime? time;
    _Coordinates? result;

    final timer = Stopwatch()..start();
    try {
      await for (final reading
          in Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
            ),
          ).timeout(
            const Duration(seconds: 6),
            onTimeout: (sink) => sink.close(),
          )) {
        // Fake GPS apps are not accepted
        if (reading.isMocked) {
          ConstantSnackbar.showError(
            title: 'Fake location detected. Turn off mock location apps.',
          );
          return null;
        }
        // Readings worse than 40 m only add noise
        if (reading.accuracy > 40 || reading.accuracy <= 0) continue;

        final weight = 1 / (reading.accuracy * reading.accuracy);
        weightSum += weight;
        latSum += reading.latitude * weight;
        lngSum += reading.longitude * weight;
        if (bestAccuracy == null || reading.accuracy < bestAccuracy) {
          bestAccuracy = reading.accuracy;
          altitude = reading.altitude;
        }
        time = reading.timestamp;

        result = (
          latitude: latSum / weightSum,
          longitude: lngSum / weightSum,
          accuracy: bestAccuracy,
          altitude: altitude,
          capturedAt: time,
        );
        _coordinates.value = result;

        if (timer.elapsed >= _readTime || bestAccuracy <= _stopAccuracy) break;
      }
    } catch (e) {
      logDebug('Error reading office location: $e');
    }
    return result;
  }

  // Street address for the coordinates, or null when it cannot be found
  Future<String?> _addressFor(double latitude, double longitude) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return null;
      final place = places.first;
      final parts = <String>[];
      for (final part in [
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.postalCode,
        place.country,
      ]) {
        final text = part?.trim() ?? '';
        if (text.isNotEmpty && !parts.contains(text)) parts.add(text);
      }
      return parts.isEmpty ? null : parts.join(', ');
    } catch (e) {
      logDebug('Error finding address: $e');
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final coordinates = _coordinates.value;
    if (coordinates == null) {
      ConstantSnackbar.showError(
        title: 'Tap "Use my current location" while at the office',
      );
      return;
    }

    final org = context.read<OrganizationProvider>();
    final location = OfficeLocationModel(
      name: _name.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      radiusMeters: double.parse(_radius.text.trim()),
    );

    final saved = await org.saveOfficeLocation(location);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      ConstantSnackbar.showSuccess(title: 'Office location saved');
    } else {
      ConstantSnackbar.showError(title: 'Failed to save office location');
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
    );
  }

  // The captured reading, shown so the admin can judge it before saving
  Widget _coordinatesDetails(_Coordinates? coordinates) {
    if (coordinates == null) {
      return Text(
        'Location not set yet',
        style: getTextTheme().labelSmall?.copyWith(
          color: ConstColors.inProgressOrange,
        ),
      );
    }

    final rows = <MapEntry<String, String>>[
      MapEntry('Latitude', coordinates.latitude.toStringAsFixed(7)),
      MapEntry('Longitude', coordinates.longitude.toStringAsFixed(7)),
      if (coordinates.accuracy != null)
        MapEntry('Accuracy', '±${coordinates.accuracy!.round()} m'),
      if (coordinates.altitude != null)
        MapEntry('Altitude', '${coordinates.altitude!.round()} m'),
      if (coordinates.capturedAt != null)
        MapEntry(
          'Captured at',
          DateFormat('dd MMM, hh:mm:ss a').format(coordinates.capturedAt!),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: ConstColors.lightShade,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            coordinates.accuracy == null
                ? 'Saved location'
                : 'Location captured',
            style: getTextTheme().labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: ConstColors.textColor,
            ),
          ),
          SizedBox(height: 6.h),
          for (final row in rows)
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 90.w,
                    child: Text(
                      row.key,
                      style: getTextTheme().labelSmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: getTextTheme().labelSmall?.copyWith(
                        color: ConstColors.textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<OrganizationProvider, bool>(
      selector: (_, org) => org.isSavingOfficeLocation,
      builder: (context, isSaving, _) {
        return Padding(
          // Lifts the sheet above the keyboard
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: ConstColors.borderColor,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Container(
                          width: 40.r,
                          height: 40.r,
                          decoration: BoxDecoration(
                            color: ConstColors.lightShade,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 22.r,
                            color: ConstColors.primaryDeep,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Office Location',
                                style: getTextTheme().titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: ConstColors.textColor,
                                ),
                              ),
                              Text(
                                'Stand inside the office when you set it',
                                style: getTextTheme().labelSmall?.copyWith(
                                  color: ConstColors.textColorLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration('Office name'),
                    validator: Validators.required('the office name'),
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _address,
                    maxLines: 2,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration('Address (optional)'),
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _radius,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _decoration('Allowed radius (metres)'),
                    validator: Validators.decimalInRange('radius', 10, 1000),
                  ),
                  SizedBox(height: 12.h),
                  ChangeNotifierProvider.value(
                    value: _locating,
                    child: Consumer<ToggleProvider>(
                      builder: (context, locating, _) => ConstantButton(
                        text: 'Use my current location',
                        isOutlined: true,
                        isLoading: locating.value,
                        icon: Icon(
                          Icons.my_location,
                          size: 18.r,
                          color: ConstColors.primaryDeep,
                        ),
                        onPressed: locating.value || isSaving
                            ? null
                            : _useCurrentLocation,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  ChangeNotifierProvider.value(
                    value: _coordinates,
                    child: Selector<ValueProvider<_Coordinates?>, _Coordinates?>(
                      selector: (_, value) => value.value,
                      builder: (context, coordinates, _) =>
                          _coordinatesDetails(coordinates),
                    ),
                  ),
                    SizedBox(height: 16.h),
                    ConstantButton(
                      text: 'Save Office Location',
                      isLoading: isSaving,
                      onPressed: isSaving ? null : _save,
                      backgroundColor: ConstColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
