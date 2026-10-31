/// Um registro de consumo de água (equivalente ao objeto salvo no IndexedDB do PWA).
class WaterRecord {
  final int? id;
  final DateTime timestamp;
  final int amount; // ml
  final String type; // "Copo", "Garrafa", "Personalizado", "Lembrete do Alarme"...

  const WaterRecord({
    this.id,
    required this.timestamp,
    required this.amount,
    required this.type,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'amount': amount,
        'type': type,
      };

  factory WaterRecord.fromMap(Map<String, Object?> map) => WaterRecord(
        id: map['id'] as int?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        amount: map['amount'] as int,
        type: map['type'] as String,
      );
}
