import 'package:flutter_test/flutter_test.dart';
import 'package:timebloc_clone/app_state.dart';
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

  test('Garantie Zero-Conflit: resolveAllConflicts résout les chevauchements en cascade', () {
    final s = AppState();
    final d = DateTime(2026, 10, 18);
    final dateStr = dateKey(d);

    // Ajouter 3 blocs intentionnellement en conflit
    // Bloc 1: 10:00 (600) -> 11:30 (690)
    // Bloc 2: 10:30 (630) -> 12:00 (720) [chevauche Bloc 1]
    // Bloc 3: 11:00 (660) -> 12:30 (750) [chevauche Bloc 1 & 2]
    s.blocks.addAll([
      TimeBlock(id: 'b1', title: 'Bloc 1', colorValue: 0, startMin: 600, endMin: 690, date: dateStr),
      TimeBlock(id: 'b2', title: 'Bloc 2', colorValue: 0, startMin: 630, endMin: 720, date: dateStr),
      TimeBlock(id: 'b3', title: 'Bloc 3', colorValue: 0, startMin: 660, endMin: 750, date: dateStr),
    ]);

    expect(s.getConflictingBlockIds(d).isNotEmpty, true);

    // Résolution
    final count = s.resolveAllConflicts(d);
    expect(count > 0, true);

    // Vérifier 0 conflit restant
    expect(s.getConflictingBlockIds(d).isEmpty, true);

    final sorted = s.blocksFor(d);
    expect(sorted[0].startMin, 600);
    expect(sorted[0].endMin, 690);
    expect(sorted[1].startMin >= sorted[0].endMin, true);
    expect(sorted[2].startMin >= sorted[1].endMin, true);
  });

  test('Garantie Zero-Conflit: findNextAvailableSlot trouve le premier créneau libre', () {
    final s = AppState();
    final dateStr = '2026-10-18';
    s.blocks.addAll([
      TimeBlock(id: 'b1', title: 'Bloc 1', colorValue: 0, startMin: 540, endMin: 600, date: dateStr), // 9h - 10h
      TimeBlock(id: 'b2', title: 'Bloc 2', colorValue: 0, startMin: 630, endMin: 720, date: dateStr), // 10h30 - 12h
    ]);

    // Cas 1 : Créneau libre de 30 min entre 10h et 10h30 demandé à 9h30
    final slot1 = s.findNextAvailableSlot(dateStr, 30, preferredStart: 570);
    expect(slot1.$1, 600); // 10h00
    expect(slot1.$2, 630); // 10h30

    // Cas 2 : Créneau de 60 min demandé à 9h30 (ne rentre pas dans le trou de 30 min)
    final slot2 = s.findNextAvailableSlot(dateStr, 60, preferredStart: 570);
    expect(slot2.$1, 720); // 12h00
    expect(slot2.$2, 780); // 13h00
  });
}
