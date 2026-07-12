import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';
import '../../core/local_repository.dart';

class FormTarjeta extends StatefulWidget {
  final Map<String, dynamic>? tarjeta;
  final VoidCallback onSave;
  const FormTarjeta({super.key, this.tarjeta, required this.onSave});

  @override
  State<FormTarjeta> createState() => _FormTarjetaState();
}

class _FormTarjetaState extends State<FormTarjeta> {
  final _form   = GlobalKey<FormState>();
  final _banco  = TextEditingController();
  final _nombre = TextEditingController();
  final _cupo   = TextEditingController();
  final _corte  = TextEditingController();
  final _pago   = TextEditingController();
  final _tasa   = TextEditingController();
  final _pctAvances = TextEditingController(text: '100');
  final _cuotaManejo = TextEditingController(text: '0');
  bool  _saving = false;

  @override
  void initState() {
    super.initState();
    _banco.addListener(_onBancoChanged);
    if (widget.tarjeta != null) {
      final t = widget.tarjeta!;
      _banco.text  = t['banco']?.toString() ?? '';
      _nombre.text = t['nombre_tarjeta']?.toString() ?? '';
      _cupo.text   = t['cupo_total']?.toString() ?? '';
      _corte.text  = t['fecha_corte']?.toString() ?? '';
      _pago.text   = t['fecha_pago']?.toString() ?? '';
      _tasa.text   = t['tasa_interes_mensual']?.toString() ?? '';
      _pctAvances.text = t['cupo_avances_total']?.toString() ?? '0';
      _cuotaManejo.text = t['cuota_manejo']?.toString() ?? '0';
    }
  }

  @override
  void dispose() {
    _banco.removeListener(_onBancoChanged);
    super.dispose();
  }

  void _onBancoChanged() {
    _autoFillTasa();
  }

  void _autoFillTasa() {
    final b = _banco.text.toLowerCase();
    if (_tasa.text == '0' || _tasa.text.isEmpty) {
      if (b.contains('nu') || b.contains('nubank')) {
        _tasa.text = '2.11';
      } else if (b.contains('rappi') || b.contains('rappicard')) {
        _tasa.text = '2.07';
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              Text(widget.tarjeta == null ? 'Nueva tarjeta de credito' : 'Editar tarjeta',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),
              _Field(ctrl: _banco,  label: 'Banco',        hint: 'Ej: Bancolombia'),
              _Field(ctrl: _nombre, label: 'Nombre',       hint: 'Ej: Visa Oro'),
              _Field(ctrl: _cupo,   label: 'Cupo total',   hint: '5000000', keyboardType: TextInputType.number),
              Row(children: [
                Expanded(child: _Field(ctrl: _corte, label: 'Dia de corte',  hint: '15', keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _pago,  label: 'Dia de pago (opcional)', hint: 'Calculado auto.', keyboardType: TextInputType.number, isRequired: false)),
              ]),
              _Field(ctrl: _tasa, label: 'Tasa mensual por defecto (%)', hint: '1.8', keyboardType: TextInputType.number),
              Row(children: [
                Expanded(child: _Field(ctrl: _pctAvances, label: 'Cupo Avances (\$)', hint: '2460736', keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _cuotaManejo, label: 'Cuota de manejo (\$)', hint: '0', keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                 : const Text('Guardar tarjeta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      int corte = int.parse(_corte.text);
      int pago = 0;
      if (_pago.text.isNotEmpty) {
        pago = int.parse(_pago.text);
      } else {
        pago = corte + 15;
        if (pago > 30) pago -= 30;
      }

      final data = {
        'banco':                _banco.text.trim(),
        'nombre_tarjeta':       _nombre.text.trim(),
        'color':                getTarjetaColorHex({'banco': _banco.text.trim(), 'nombre_tarjeta': _nombre.text.trim()}),
        'cupo_total':           double.parse(_cupo.text),
        'fecha_corte':          corte,
        'fecha_pago':           pago,
        'tasa_interes_mensual': double.parse(_tasa.text.isEmpty ? '0' : _tasa.text),
        'cupo_avances_total':   double.parse(_pctAvances.text.isEmpty ? '0' : _pctAvances.text),
        'cuota_manejo':         double.parse(_cuotaManejo.text.isEmpty ? '0' : _cuotaManejo.text),
      };

      if (widget.tarjeta != null) {
        await LocalRepository.instance.updateTarjeta(widget.tarjeta!['id'] as int, data);
      } else {
        await LocalRepository.instance.createTarjeta(data);
      }
      
      if (mounted) { Navigator.pop(context); widget.onSave(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: '), backgroundColor: AppTheme.colorGastos));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class FormCompra extends StatefulWidget {
  final int      tarjetaId;
  final double   tasaDefecto;
  final Map<String, dynamic>? compra;
  final VoidCallback onSave;
  const FormCompra({super.key, required this.tarjetaId, required this.tasaDefecto, this.compra, required this.onSave});

  @override
  State<FormCompra> createState() => _FormCompraState();
}

class _FormCompraState extends State<FormCompra> {
  final _form       = GlobalKey<FormState>();
  final _desc       = TextEditingController();
  final _comercio   = TextEditingController();
  final _monto      = TextEditingController();
  final _cuotas     = TextEditingController(text: '1');
  final _tasa       = TextEditingController();
  final _fecha      = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
  String _tipoTasa  = 'MENSUAL';
  bool   _esAvance  = false;
  bool   _saving    = false;

  @override
  void initState() {
    super.initState();
    if (widget.compra != null) {
      final c = widget.compra!;
      _desc.text = (c['descripcion']?.toString() ?? '').replaceAll(RegExp(r'^\(Avance\)\s*'), '');
      _comercio.text = c['comercio']?.toString() ?? '';
      _monto.text = c['monto_total']?.toString() ?? '';
      _cuotas.text = c['num_cuotas']?.toString() ?? '1';
      _tasa.text = ((c['tasa_interes_mensual'] as num? ?? 0) * 100).toStringAsFixed(2);
      _fecha.text = c['fecha_compra']?.toString() ?? '';
      _tipoTasa = c['tipo_tasa_ingresada']?.toString() ?? 'MENSUAL';
      _esAvance = (c['es_avance'] as int? ?? 0) == 1;
    } else {
      _tasa.text = widget.tasaDefecto.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              const Text('Registrar compra',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Es un avance de efectivo', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                value: _esAvance,
                onChanged: (val) => setState(() => _esAvance = val),
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              _Field(ctrl: _desc,    label: _esAvance ? 'Motivo del avance' : 'Descripcion',    hint: _esAvance ? 'Ej: Efectivo para viaje' : 'Ej: Televisor Samsung'),
              if (!_esAvance) _Field(ctrl: _comercio,label: 'Comercio',        hint: 'Ej: Exito (opcional)'),
              _Field(ctrl: _monto,   label: 'Monto total',    hint: '1500000', keyboardType: TextInputType.number),
              _Field(ctrl: _cuotas,  label: 'Numero de cuotas', hint: '12', keyboardType: TextInputType.number),

              Row(children: [
                Expanded(child: _Field(ctrl: _tasa, label: 'Tasa de interes (%)', hint: '1.8', keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value:       _tipoTasa,
                    decoration:  const InputDecoration(labelText: 'Tipo de tasa'),
                    dropdownColor: AppTheme.surfaceColor,
                    style:       const TextStyle(color: AppTheme.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'MENSUAL', child: Text('Mensual')),
                      DropdownMenuItem(value: 'EA',      child: Text('E.A. Anual')),
                    ],
                    onChanged: (v) => setState(() => _tipoTasa = v!),
                  ),
                ),
              ]),
              _Field(ctrl: _fecha, label: 'Fecha de compra', hint: 'YYYY-MM-DD'),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'El sistema calculara automaticamente la tabla de amortizacion con el sistema de cuota fija (Frances) y la proyectara mes a mes.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                 : const Text('Generar amortizacion y guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final descFinal = _esAvance ? '(Avance) ' : _desc.text.trim();
      final comercioFinal = _esAvance ? 'Avance en efectivo' : _comercio.text.trim();

      final reqData = {
        'descripcion':    descFinal,
        'comercio':       comercioFinal,
        'monto_total':    double.parse(_monto.text),
        'num_cuotas':     int.parse(_cuotas.text),
        'tasa_ingresada': double.parse(_tasa.text.isEmpty ? '0' : _tasa.text),
        'tipo_tasa':      _tipoTasa,
        'fecha_compra':   _fecha.text,
        'es_avance':      _esAvance,
      };

      final result = widget.compra == null
          ? await LocalRepository.instance.createCompra(widget.tarjetaId, reqData)
          : await LocalRepository.instance.updateCompra(widget.tarjetaId, widget.compra!['id'] as int, reqData);

      if (result['ok'] == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['error'] ?? 'No se pudo registrar la compra.'}'),
              backgroundColor: AppTheme.colorGastos,
            ),
          );
        }
        setState(() => _saving = false);
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSave();
        final cuotaFija = result['data']?['cuota_fija'];
        if (cuotaFija != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Amortizacion generada. Cuota mensual: ${formatCOP(cuotaFija)}'),
              backgroundColor: AppTheme.colorAlDia,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos)
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String                label;
  final String                hint;
  final TextInputType         keyboardType;
  final bool                  isRequired;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller:  ctrl,
      keyboardType: keyboardType,
      style:       const TextStyle(color: AppTheme.textPrimary),
      decoration:  InputDecoration(labelText: label, hintText: hint),
      validator:   (v) => isRequired && (v == null || v.trim().isEmpty) ? 'Requerido' : null,
    ),
  );
}
