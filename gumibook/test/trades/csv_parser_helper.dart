/// Minimal RFC 4180 CSV parser used by export tests to prove quoted
/// fields (comma, doubled quote, embedded newline) round-trip as a
/// single logical cell.
class CsvParser {
  List<List<String>> parse(String input) {
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    var i = 0;
    var inQuotes = false;

    void endField() {
      row.add(field.toString());
      field = StringBuffer();
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    while (i < input.length) {
      final ch = input[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        field.write(ch);
        i++;
        continue;
      }
      if (ch == '"' && field.isEmpty) {
        inQuotes = true;
        i++;
        continue;
      }
      if (ch == ',') {
        endField();
        i++;
        continue;
      }
      if (ch == '\n' || ch == '\r') {
        if (field.isNotEmpty || row.isNotEmpty) endRow();
        i++;
        continue;
      }
      field.write(ch);
      i++;
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }
}
