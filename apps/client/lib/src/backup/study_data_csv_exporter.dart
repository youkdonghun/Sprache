import 'package:csv/csv.dart';

import '../domain/learning_item.dart';
import 'study_data_export_table.dart';

class StudyDataCsvExporter {
  const StudyDataCsvExporter({this.table = const StudyDataExportTable()});

  final StudyDataExportTable table;

  String encode(Iterable<LearningItem> items) =>
      Csv(addBom: true).encode(table.rows(items));
}
