import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/suscripcion.dart';
import '../core/local_repository.dart';

final suscripcionesProvider = FutureProvider<List<Suscripcion>>((ref) async {
  final rows = await LocalRepository.instance.getSuscripciones();
  return rows.map((r) => Suscripcion.fromMap(r)).toList();
});
