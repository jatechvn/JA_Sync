import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) return;
  final rootPath = args[0];
  print("Testing scan on: $rootPath");
  
  final root = Directory(rootPath);
  if (!root.existsSync()) return;

  int count = 0;
  List<Directory> dirsToScan = [root];
  
  try {
    while (dirsToScan.isNotEmpty) {
      final currentDir = dirsToScan.removeLast();
      try {
        final entities = currentDir.listSync(recursive: false, followLinks: false);
        for (final entity in entities) {
          count++;
          entity.statSync();
          if (entity is Directory) {
            dirsToScan.add(entity);
          }
        }
      } catch (e) {
        print("Error at ${currentDir.path}: $e");
      }
    }
    print("Scanned $count items with listSync.");
  } catch (e) {
    print("Fatal error: $e");
  }
}
