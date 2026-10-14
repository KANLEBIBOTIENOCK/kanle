import 'package:flutter_test/flutter_test.dart';
import 'package:timebloc_clone/models.dart';

void main() {
  test('fmtMin formate les minutes en HH:mm', () {
    expect(fmtMin(65), '01:05');
  });

  test('TimeBlock JSON round-trip avec catégorie et notifId', () {
    final b = TimeBlock(
      id: '1',
      title: 'Prière du matin',
      colorValue: 0xFFE2B93B,
      startMin: 360,
      endMin: 420,
      date: '2026-10-13',
      categoryId: 'prayer',
    );
    final c = TimeBlock.fromJson(b.toJson());
    expect(c.title, 'Prière du matin');
    expect(c.duration, 60);
    expect(c.category.id, 'prayer');
    expect(c.category.name, 'Prière & Foi');
    expect(c.notifId > 0, true);
  });
}
