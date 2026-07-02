import '../models/document.dart';

class DocumentRepository {

  final List<Document> documents = [

    Document(

      id: "1",

      title: "السجل التجاري",

      number: "CR-1001",

      expiryDate: DateTime(2027,1,10),

      expired: false,

    ),

    Document(

      id: "2",

      title: "رخصة البلدية",

      number: "BL-202",

      expiryDate: DateTime(2026,8,5),

      expired: false,

    ),

    Document(

      id: "3",

      title: "شهادة الدفاع المدني",

      number: "CD-501",

      expiryDate: DateTime(2026,7,25),

      expired: true,

    ),

  ];

}