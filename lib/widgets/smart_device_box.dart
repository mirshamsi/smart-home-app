// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:topaz/providers/device_provider.dart';

// class SmartDeviceBox extends StatefulWidget {
//   final String smartDeviceName;
//   final String iconPath;
//   final bool powerOn;
//   final void Function(bool)? onChanged;
//   final int relayNumber;
//   final String deviceId;

//   const SmartDeviceBox({
//     super.key,
//     required this.smartDeviceName,
//     required this.iconPath,
//     required this.powerOn,
//     required this.onChanged,
//     required this.relayNumber,
//     required this.deviceId,
//   });

//   @override
//   State<SmartDeviceBox> createState() => _SmartDeviceBoxState();
// }

// class _SmartDeviceBoxState extends State<SmartDeviceBox> {
//   // Memoize the decoration to avoid rebuilding it unnecessarily
//   BoxDecoration? _cachedDecoration;
//   bool _lastState = false;

//   @override
//   void initState() {
//     super.initState();
//     _lastState = widget.powerOn;
//     _updateDecoration(_lastState);
//   }

//   @override
//   void didUpdateWidget(SmartDeviceBox oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.powerOn != _lastState) {
//       _lastState = widget.powerOn;
//       _updateDecoration(_lastState);
//     }
//   }

//   void _updateDecoration(bool currentState) {
//     _cachedDecoration = BoxDecoration(
//       borderRadius: BorderRadius.circular(24),
//       color: currentState
//           ? Colors.grey[900]
//           : const Color.fromARGB(44, 164, 167, 189),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Using Consumer to optimize rebuilds - only rebuilds when the specific device state changes
//     return Consumer<DeviceProvider>(
//       builder: (context, deviceProvider, child) {
//         // Read the state as String and convert to bool
//         final String stateString =
//             deviceProvider.getButtonStates(
//               widget.deviceId,
//             )[widget.relayNumber] ??
//             "0";
//         final bool currentState = stateString == "1";

//         // Update decoration if state changed
//         if (currentState != _lastState) {
//           _lastState = currentState;
//           _updateDecoration(currentState);
//         }

//         return Padding(
//           padding: const EdgeInsets.all(15.0),
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 200),
//             decoration: _cachedDecoration,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(vertical: 25.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   // icon
//                   Image.asset(
//                     widget.iconPath,
//                     height: 65,
//                     color: currentState ? Colors.green : Colors.red,
//                   ),

//                   // smart device name + switch
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Padding(
//                           padding: const EdgeInsets.only(right: 20.0),
//                           child: Text(
//                             widget.smartDeviceName,
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 20,
//                               color: currentState ? Colors.white : Colors.black,
//                             ),
//                           ),
//                         ),
//                       ),
//                       CupertinoSwitch(
//                         value: currentState,
//                         onChanged: widget.onChanged,
//                         activeColor: Colors.green,
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   @override
//   void dispose() {
//     // Clean up any resources if needed
//     super.dispose();
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:topaz/providers/device_provider.dart';

class SmartDeviceBox extends StatelessWidget {
  final String smartDeviceName;
  final String iconPath;
  final bool powerOn;
  final void Function(bool)? onChanged;
  final int relayNumber;
  final String deviceId;

  const SmartDeviceBox({
    super.key,
    required this.smartDeviceName,
    required this.iconPath,
    required this.powerOn,
    required this.onChanged,
    required this.relayNumber,
    required this.deviceId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final String stateString =
            deviceProvider.getButtonStates(deviceId)[relayNumber] ?? "0";

        final bool isOn = stateString == "1";

        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: isOn ? colorScheme.primaryContainer : colorScheme.surface,
            border: Border.all(
              color: isOn
                  ? colorScheme.primary.withOpacity(0.35)
                  : colorScheme.outlineVariant.withOpacity(0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: isOn
                    ? colorScheme.primary.withOpacity(0.18)
                    : Colors.black.withOpacity(0.06),
                blurRadius: isOn ? 26 : 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOn
                          ? colorScheme.primary.withOpacity(0.18)
                          : colorScheme.surfaceVariant.withOpacity(0.7),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        iconPath,
                        color: isOn
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: isOn
                          ? Colors.green.withOpacity(0.14)
                          : Colors.red.withOpacity(0.12),
                    ),
                    child: Text(
                      isOn ? 'روشن' : 'خاموش',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isOn ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                smartDeviceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isOn
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'رله $relayNumber',
                style: TextStyle(
                  fontSize: 12,
                  color: isOn
                      ? colorScheme.onPrimaryContainer.withOpacity(0.75)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'وضعیت',
                    style: TextStyle(
                      fontSize: 13,
                      color: isOn
                          ? colorScheme.onPrimaryContainer.withOpacity(0.75)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(value: isOn, onChanged: onChanged),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
