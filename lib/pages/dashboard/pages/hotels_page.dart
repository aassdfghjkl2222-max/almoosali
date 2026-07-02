import 'package:flutter/material.dart';

import '../../../repositories/hotel_repository.dart';
import '../widgets/hotel_card.dart';
import 'hotel_details_page.dart';

class HotelsPage extends StatelessWidget {
  const HotelsPage({super.key});

  @override
  Widget build(BuildContext context) {

    final repository = HotelRepository();

    return ListView.builder(

      padding: const EdgeInsets.all(16),

      itemCount: repository.hotels.length,

      itemBuilder: (context, index) {

        final hotel = repository.hotels[index];

        return Padding(

          padding: const EdgeInsets.only(bottom: 12),

          child: HotelCard(

            hotel: hotel,

            onTap: () {

              Navigator.push(

                context,

                MaterialPageRoute(

                  builder: (_) => HotelDetailsPage(

                    hotel: hotel,

                  ),

                ),

              );

            },

          ),

        );

      },

    );

  }

}