import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PasswordStore {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/password.txt');

    print("PASSWORD DIR = ${dir.path}");
    print("PASSWORD FILE = ${file.path}");

    return file.create(recursive: true);
  }

  static Future<String> read() async {
    final f = await _file();

    if (!await f.exists()) {
      print("PASSWORD FILE DOES NOT EXIST");
      return '';
    }

    final content = await f.readAsString();
    print("PASSWORD RAW CONTENT = '$content'");
    print(
        "PASSWORD TRIMMED = '${content.trim()}' (len=${content.trim().length})");

    return content;
  }

  static Future<void> write(String password) async {
    final f = await _file();
    await f.writeAsString(password);
    print("PASSWORD WRITTEN = '$password'");
  }

  static Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) {
      await f.delete();
      print("PASSWORD FILE DELETED");
    } else {
      print("PASSWORD FILE NOT FOUND TO DELETE");
    }
  }
}
