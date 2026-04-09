import 'package:hive/hive.dart';

void main() {
  try {
    print(Hive.isBoxOpen('test'));
  } catch (e) {
    print('Error: $e');
  }
}
