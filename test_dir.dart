import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) return;
  final rootPath = args[0];
  stdout.writeln('Testing scan on: $rootPath');

  final root = Directory(rootPath);
  if (!root.existsSync()) return;

  int count = 0;
  final dirsToScan = <Directory>[root];

  try {
    while (dirsToScan.isNotEmpty) {
      final currentDir = dirsToScan.removeLast();
      try {
        final entities = currentDir.listSync(
          recursive: false,
          followLinks: false,
        );
        for (final entity in entities) {
          count++;
          entity.statSync();
          if (entity is Directory) {
            dirsToScan.add(entity);
          }
        }
      } catch (e) {
        stderr.writeln('Error at ${currentDir.path}: $e');
      }
    }
    stdout.writeln('Scanned $count items with listSync.');
  } catch (e) {
    stderr.writeln('Fatal error: $e');
  }
}
