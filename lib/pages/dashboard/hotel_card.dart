import 'package:flutter/material.dart';

import '../../../models/hotel.dart';

class HotelCard extends StatelessWidget {
  final Hotel hotel;
  final VoidCallback onTap;

  const HotelCard({
    super.key,
    required this.hotel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.hotel),
        ),
        title: Text(hotel.arabicName),
        subtitle: Text(hotel.englishName),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}