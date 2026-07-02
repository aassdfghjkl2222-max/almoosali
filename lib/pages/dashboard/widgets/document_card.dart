import 'package:flutter/material.dart';

import '../../../models/document.dart';

class DocumentCard extends StatelessWidget {

  final Document document;

  final VoidCallback onTap;

  const DocumentCard({

    super.key,

    required this.document,

    required this.onTap,

  });

  @override
  Widget build(BuildContext context) {

    return Card(

      child: ListTile(

        onTap: onTap,

        leading: CircleAvatar(

          backgroundColor:

          document.expired

              ? Colors.red

              : Colors.green,

          child: const Icon(

            Icons.description,

            color: Colors.white,

          ),

        ),

        title: Text(document.title),

        subtitle: Text(document.number),

        trailing: Text(

          document.expired

              ? "منتهي"

              : "ساري",

          style: TextStyle(

            color:

            document.expired

                ? Colors.red

                : Colors.green,

            fontWeight: FontWeight.bold,

          ),

        ),

      ),

    );

  }

}