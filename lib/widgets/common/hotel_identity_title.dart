import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';

class HotelIdentityTitle extends StatelessWidget {
  final String title;
  final Hotel hotel;
  final Color? color;

  const HotelIdentityTitle({
    super.key,
    required this.title,
    required this.hotel,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final identityColor = color ?? HotelVisualIdentity.colorForHotel(hotel);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: identityColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                hotel.arabicName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
