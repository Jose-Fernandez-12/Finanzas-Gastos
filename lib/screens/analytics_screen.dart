import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_provider.dart';
import '../providers/analytics_profile_provider.dart';
import '../providers/virtual_assistant_provider.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../core/local_repository.dart';
import 'dart:math' as math;
import 'reporte_detallado_screen.dart';
import '../widgets/common_widgets.dart';
import '../providers/proyeccion_capacidad_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedMonth = mesActual();
  List<dynamic> _gastosDelMes = [];
  double _mesIngresos = 0.0;
  double _mesEgresos = 0.0;
  bool _loadingGastos = false;
  double _pctAbonoExtra = 0.0;
  double _abonoSimulador = 200000.0;
  bool _simuladorAvalancha = true;
  String _proyeccionSelectedMonth = sumMonths(mesActual(), 1);
  int _proyeccionOffset = 1;

  Map<String, dynamic>? _lastProviderData;
  Map<String, dynamic>? _lastAdvData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchGastosDelMes();
      ref.read(virtualAssistantProvider.notifier).setCurrentView('analitica');
    });
  }

  Future<void> _fetchGastosDelMes({bool silently = false}) async {
    if (!silently) setState(() => _loadingGastos = true);
    try {
      final rGastos = await LocalRepository.instance.getGastosFijos(mes: _selectedMonth);
      final List<dynamic> gastos = rGastos['data'] ?? [];
      double totalGastos = 0.0;
      for (var g in gastos) { totalGastos += (g['monto'] as num?)?.toDouble() ?? 0.0; }

      final rIngresos = await LocalRepository.instance.getIngresos(mes: _selectedMonth);
      final List<dynamic> ingresos = rIngresos['data'] ?? [];
      double totalIngresos = 0.0;
      for (var i in ingresos) { totalIngresos += (i['monto'] as num?)?.toDouble() ?? 0.0; }

      if (mounted) {
        setState(() {
          _gastosDelMes = gastos;
          _mesIngresos = totalIngresos;
          _mesEgresos = totalGastos;
        });
      }
    } catch (e) {
      debugPrint("Error loading data for analytics month $_selectedMonth: $e");
    } finally {
      if (mounted && !silently) setState(() => _loadingGastos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(analyticsProvider(_pctAbonoExtra));
    final advancedAsync = ref.watch(advancedAnalyticsProvider((mes: _selectedMonth, abonoExtra: _abonoSimulador)));
    final profileState = ref.watch(analyticsProfileProvider);

    // Extraemos el valor actual y guardamos el último conocido.
    // Al cambiar un parámetro (ej. _abonoSimulador), Riverpod crea un provider nuevo sin datos previos.
    // Usamos el caché local para no perder la vista.
    if (analyticsAsync.hasValue) _lastProviderData = analyticsAsync.value;
    if (advancedAsync.hasValue) _lastAdvData = advancedAsync.value;

    final providerData = analyticsAsync.value ?? _lastProviderData;
    final advData = advancedAsync.value ?? _lastAdvData;
    final isReloading = analyticsAsync.isLoading || advancedAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analíticas Pro', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          // Selector de perfil
          _buildProfileSelector(profileState),
          // Botón personalizar
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.primary),
            tooltip: 'Personalizar Vista',
            onPressed: () => _showCustomizeSheet(context, profileState),
          ),
        ],
      ),
      backgroundColor: AppTheme.bgCanvas,
      body: _loadingGastos
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : providerData == null
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : Column(
                  children: [
                    // Indicador de recarga discreto (sin destruir la UI)
                    if (isReloading)
                      LinearProgressIndicator(
                        backgroundColor: AppTheme.borderLight,
                        color: AppTheme.primary,
                        minHeight: 2,
                      ),
                    Expanded(
                      child: profileState.perfilActivoId == 'perfil_reporte'
                          ? const ReporteDetalladoView()
                          : _buildContent(providerData!, advData, profileState.modulosActivos),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProfileSelector(AnalyticsProfileState profileState) {
    return PopupMenuButton<String>(
      onSelected: (id) {
        ref.read(analyticsProfileProvider.notifier).seleccionarPerfil(id);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.bgCard,
      itemBuilder: (context) => [
        ...profileState.perfiles.map((p) => PopupMenuItem<String>(
          value: p.id,
          child: Row(
            children: [
              Icon(
                p.id == profileState.perfilActivoId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: p.id == profileState.perfilActivoId ? AppTheme.primary : AppTheme.textMuted,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(p.nombre, style: TextStyle(
                color: p.id == profileState.perfilActivoId ? AppTheme.primary : AppTheme.textPrimary,
                fontWeight: p.id == profileState.perfilActivoId ? FontWeight.w700 : FontWeight.normal,
                fontSize: 13,
              ))),
              if (p.esPorDefecto)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.secondary.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                  child: const Text('default', style: TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        )),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '__manage__',
          child: const Row(
            children: [
              Icon(Icons.manage_accounts_rounded, color: AppTheme.primary, size: 18),
              SizedBox(width: 10),
              Text('Gestionar Perfiles', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          onTap: () => _showManageProfilesSheet(context, profileState),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_rounded, color: AppTheme.primary, size: 15),
            const SizedBox(width: 5),
            Text(
              profileState.perfilActivo.nombre,
              style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> provider, Map<String, dynamic>? adv, Set<String> modulos) {
    final historical = [
      {'label': _selectedMonth, 'ingresos': _mesIngresos, 'egresos': _mesEgresos}
    ];
    final proyeccion = provider['proyeccion'] as List<dynamic>? ?? [];

    final double deudaTarjetas = (provider['deuda_tarjetas'] as num?)?.toDouble() ?? 0.0;
    final double cuentasPorCobrar = (provider['cuentas_por_cobrar'] as num?)?.toDouble() ?? 0.0;
    final double endeudamientoPct = (deudaTarjetas + cuentasPorCobrar) > 0
        ? (deudaTarjetas / (deudaTarjetas + cuentasPorCobrar) * 100)
        : 0.0;
    final String nivelRiesgo = endeudamientoPct > 60 ? 'Alto' : endeudamientoPct > 35 ? 'Medio' : 'Bajo';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMonthSelector(),
          const SizedBox(height: 16),

          // Alerta de estrés siempre visible (banner)
          if (adv != null && adv['estres'] != null) ...[
            _buildAlertaEstresBanner(adv['estres'] as Map<String, dynamic>),
            const SizedBox(height: 16),
          ],

          // Termómetro
          if (modulos.contains(AnalyticsModuleIds.termometro) && adv != null && adv['termometro'] != null) ...[
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('termometro', adv['termometro'] as Map<String, dynamic>),
              child: _buildTermometroCard(adv['termometro'] as Map<String, dynamic>),
            ),
            const SizedBox(height: 20),
          ],

          // Calendario de estrés detallado
          if (modulos.contains(AnalyticsModuleIds.estresCash) && adv != null && adv['estres'] != null) ...[
            const _SectionTitle(title: 'Calendario de Estrés de Efectivo'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('estres_efectivo', adv['estres'] as Map<String, dynamic>),
              child: _buildCalendarioEstresCard(adv['estres'] as Map<String, dynamic>),
            ),
            const SizedBox(height: 20),
          ],

          // Endeudamiento
          if (modulos.contains(AnalyticsModuleIds.endeudamiento)) ...[
            const _SectionTitle(title: 'Estado de Endeudamiento'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('endeudamiento', {'pct': endeudamientoPct, 'nivel': nivelRiesgo}),
              child: _buildEndeudamientoCard(endeudamientoPct, nivelRiesgo, provider),
            ),
            const SizedBox(height: 20),
          ],
          
          // Proyección de Capacidad Crediticia
          const _SectionTitle(title: 'Proyección de Capacidad Crediticia'),
          const SizedBox(height: 10),
          _buildProyeccionCapacidadModule(),
          const SizedBox(height: 20),

          // Días de esclavitud financiera
          if (modulos.contains(AnalyticsModuleIds.esclavitudFinanciera) && adv != null && adv['dias_esclavitud'] != null) ...[
            const _SectionTitle(title: 'Días de Trabajo vs Obligaciones'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('dias_trabajo', adv['dias_esclavitud'] as Map<String, dynamic>),
              child: _buildEsclavitudFinancieraCard(adv['dias_esclavitud'] as Map<String, dynamic>),
            ),
            const SizedBox(height: 20),
          ],

          // Interés quemado
          if (modulos.contains(AnalyticsModuleIds.interesQuemado) && adv != null && adv['interes_quemado'] != null) ...[
            const _SectionTitle(title: 'Interés Quemado (Dinero al Banco)'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('interes_quemado', adv['interes_quemado'] as Map<String, dynamic>),
              child: _buildInteresQuemadoCard(adv['interes_quemado'] as Map<String, dynamic>),
            ),
            const SizedBox(height: 20),
          ],

          // Resumen cards
          if (modulos.contains(AnalyticsModuleIds.resumenCards)) ...[
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('resumen', {'ingresos': _mesIngresos, 'egresos': _mesEgresos}),
              child: _buildResumenCards(_mesIngresos, _mesEgresos),
            ),
            const SizedBox(height: 20),
          ],

          // Eficiencia de ahorro
          if (modulos.contains(AnalyticsModuleIds.eficienciaAhorro) && adv != null && adv['eficiencia_ahorro'] != null) ...[
            const _SectionTitle(title: 'Eficiencia de Ahorro'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('eficiencia_ahorro', adv['eficiencia_ahorro'] as Map<String, dynamic>),
              child: _buildEficienciaAhorroCard(adv['eficiencia_ahorro'] as Map<String, dynamic>),
            ),
            const SizedBox(height: 20),
          ],

          // Dependencia por tarjeta
          if (modulos.contains(AnalyticsModuleIds.dependenciaTarjetas) && adv != null && adv['dependencia_tarjetas'] != null) ...[
            const _SectionTitle(title: 'Dependencia por Tarjeta / Banco'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('dependencia_tarjetas', adv['dependencia_tarjetas'] as Map<String, dynamic>),
              child: _buildDependenciaTarjetasCard(adv['dependencia_tarjetas'] as Map<String, dynamic>),
            ),
            const SizedBox(height: 20),
          ],

          // Radar hormiga
          if (modulos.contains(AnalyticsModuleIds.radarHormiga) && adv != null && adv['radar_hormiga'] != null) ...[
            const _SectionTitle(title: 'Radar de Gastos Hormiga & Pequeñas Fugas'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('radar_hormiga', adv['radar_hormiga'] as Map<String, dynamic>),
              child: _buildRadarHormigaCard(adv['radar_hormiga'] as Map<String, dynamic>),
            ),
            const SizedBox(height: 20),
          ],

          // Flujo de caja
          if (modulos.contains(AnalyticsModuleIds.flujoCaja)) ...[
            const _SectionTitle(title: 'Flujo de Caja'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('flujo_caja', {'historical': historical}),
              child: _buildBarChart(historical),
            ),
            const SizedBox(height: 20),
          ],

          // Simulador
          if (modulos.contains(AnalyticsModuleIds.simuladorPagos) && adv != null && adv['simulador'] != null) ...[
            const _SectionTitle(title: 'Simulador Inteligente de Pagos'),
            const SizedBox(height: 10),
            if ((adv['simulador']['deudas'] as List).isNotEmpty)
              GestureDetector(
                onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('camino_cero_deuda', {'mesLibreDeDeuda': provider['mesLibreDeDeuda']?.toString() ?? 'pronto'}),
                child: _buildSimuladorDeudaCard(adv['simulador'] as Map<String, dynamic>),
              )
            else
              _buildEmptySimulador(),
            const SizedBox(height: 20),
          ],

          // Camino a cero deuda
          if (modulos.contains(AnalyticsModuleIds.caminoDeuda) && proyeccion.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(title: 'Camino a Cero Deuda'),
                const SizedBox(height: 10),
                _buildAbonoExtraSlider(provider['mesLibreDeDeuda']?.toString() ?? 'pronto'),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('camino_cero_deuda', {'mesLibreDeDeuda': provider['mesLibreDeDeuda']?.toString() ?? 'pronto', 'pctAbono': _pctAbonoExtra}),
                  child: _buildLineChart(proyeccion, provider['mesLibreDeDeuda']?.toString() ?? 'pronto'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Categorías
          if (modulos.contains(AnalyticsModuleIds.categorias)) ...[
            const _SectionTitle(title: 'Gastos por Categoría'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref.read(virtualAssistantProvider.notifier).analyzeChart('categorias', {}),
              child: _buildCategoriasCard(),
            ),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProyeccionCapacidadModule() {
    final proyeccionAsync = ref.watch(proyeccionCapacidadProvider(_proyeccionSelectedMonth));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.primary),
                onPressed: _proyeccionOffset > 1
                    ? () {
                        setState(() {
                          _proyeccionOffset--;
                          _proyeccionSelectedMonth = sumMonths(mesActual(), _proyeccionOffset);
                        });
                      }
                    : null,
              ),
              Text(
                formatMes(_proyeccionSelectedMonth),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
                onPressed: _proyeccionOffset < 6
                    ? () {
                        setState(() {
                          _proyeccionOffset++;
                          _proyeccionSelectedMonth = sumMonths(mesActual(), _proyeccionOffset);
                        });
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          proyeccionAsync.when(
            data: (data) {
              return CapacidadCrediticiaCard(
                pct: data['porcentaje_endeudamiento'] as double,
                nivel: data['nivel_riesgo'] as String,
                liquidez: data['liquidez_disponible'] as double,
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))),
            error: (e, st) => Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Error al cargar proyección.', style: TextStyle(color: AppTheme.colorGastos)))),
          ),
        ],
      ),
    );
  }

  // ─── Selector de mes ────────────────────────────────────────────────────────

  void _showMonthPicker() {
    final now = DateTime.now();
    final List<String> monthsList = [];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final year = d.year;
      final month = d.month.toString().padLeft(2, '0');
      monthsList.add('$year-$month');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecciona un Mes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: monthsList.length,
                  itemBuilder: (context, idx) {
                    final mStr = monthsList[idx];
                    final isSelected = mStr == _selectedMonth;
                    return ListTile(
                      title: Text(
                        formatMes(mStr),
                        style: TextStyle(
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: AppTheme.primary) : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() { _selectedMonth = mStr; });
                        _fetchGastosDelMes();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: _showMonthPicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(formatMes(_selectedMonth), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Banner alerta estrés ───────────────────────────────────────────────────

  Widget _buildAlertaEstresBanner(Map<String, dynamic> estres) {
    final bool alerta = estres['alerta'] as bool? ?? false;
    final String msg = estres['mensaje'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alerta ? AppTheme.colorDeudas.withAlpha(20) : AppTheme.secondary.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alerta ? AppTheme.colorDeudas : AppTheme.secondary, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(alerta ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: alerta ? AppTheme.colorDeudas : AppTheme.secondary, size: 26),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: TextStyle(
            color: alerta ? AppTheme.colorDeudas : AppTheme.textPrimary,
            fontSize: 12, fontWeight: FontWeight.w600, height: 1.35,
          ))),
        ],
      ),
    );
  }

  // ─── Termómetro ─────────────────────────────────────────────────────────────

  Widget _buildTermometroCard(Map<String, dynamic> t) {
    final double diario = (t['diario_seguro'] as num?)?.toDouble() ?? 0.0;
    final double semanal = (t['semanal_seguro'] as num?)?.toDouble() ?? 0.0;
    final double disponible = (t['disponible_real'] as num?)?.toDouble() ?? 0.0;
    final double comprometido = (t['saldo_comprometido'] as num?)?.toDouble() ?? 0.0;
    final double ingresos = (t['ingresos'] as num?)?.toDouble() ?? 0.0;
    final int dias = (t['dias_restantes'] as int?) ?? 1;
    final String estado = t['estado'] as String? ?? 'Sano';

    Color cEstado = AppTheme.secondary;
    if (estado == 'Déficit') cEstado = AppTheme.colorGastos;
    if (estado == 'Ajustado') cEstado = AppTheme.colorDeudas;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.bgCard, AppTheme.primary.withAlpha(12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withAlpha(80), width: 1.5),
        boxShadow: [BoxShadow(color: AppTheme.primary.withAlpha(18), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withAlpha(30), shape: BoxShape.circle),
                  child: const Icon(Icons.local_fire_department_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Plata Libre de Culpa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: cEstado.withAlpha(30), borderRadius: BorderRadius.circular(12), border: Border.all(color: cEstado)),
                child: Text(estado.toUpperCase(), style: TextStyle(color: cEstado, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Presupuesto diario seguro de aquí a fin de mes:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(formatCOP(diario), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              const Text('/ día', style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${formatCOP(semanal)} / sem', style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderLight, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem('Ingresos Mes', formatCOP(ingresos), AppTheme.textPrimary),
              _buildMetricItem('Comprometido', '-${formatCOP(comprometido)}', AppTheme.colorGastos),
              _buildMetricItem('Libre ($dias días)', formatCOP(disponible), cEstado),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: AppTheme.monoStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ─── Calendario de Estrés de Efectivo ──────────────────────────────────────

  Widget _buildCalendarioEstresCard(Map<String, dynamic> estres) {
    final int diaInicio = estres['dia_inicio'] as int? ?? 10;
    final int diaFin = estres['dia_fin'] as int? ?? 18;
    final int diaPico = estres['dia_pico'] as int? ?? 15;
    final double presionMonto = (estres['presion_monto'] as num?)?.toDouble() ?? 0.0;
    final double presionPct = (estres['presion_pct'] as num?)?.toDouble() ?? 0.0;
    final bool alerta = estres['alerta'] as bool? ?? false;
    final Map<String, dynamic> mapaDias = (estres['mapa_dias'] as Map<String, dynamic>?) ?? {};

    final Color mainColor = alerta ? AppTheme.colorDeudas : AppTheme.secondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: mainColor.withAlpha(25), shape: BoxShape.circle),
                child: Icon(Icons.bolt_rounded, color: mainColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alerta ? 'Zona de Alta Presión: Días $diaInicio - $diaFin' : 'Flujo de Pagos Equilibrado',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: mainColor)),
                    Text('Concentración: ${presionPct.toStringAsFixed(0)}% de los ingresos — ${formatCOP(presionMonto)}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mini-calendario visual de días 1-30
          _buildMiniCalendar(mapaDias, diaInicio, diaFin, diaPico),
          if (alerta) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.colorDeudas.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded, size: 16, color: AppTheme.colorDeudas),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Reserva fondos antes del día $diaInicio. Día de mayor pago: día $diaPico.',
                      style: const TextStyle(color: AppTheme.colorDeudas, fontSize: 11, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniCalendar(Map<String, dynamic> mapaDias, int diaInicio, int diaFin, int diaPico) {
    double maxMonto = 0.0;
    for (var v in mapaDias.values) {
      final m = (v as num?)?.toDouble() ?? 0.0;
      if (m > maxMonto) maxMonto = m;
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(30, (i) {
        final dia = i + 1;
        final monto = (mapaDias[dia.toString()] as num?)?.toDouble() ?? 0.0;
        final bool isHot = diaInicio <= dia && dia <= diaFin;
        final bool isPico = dia == diaPico;
        final double intensity = maxMonto > 0 ? monto / maxMonto : 0.0;

        Color bgColor = AppTheme.bgCardLight;
        Color textColor = AppTheme.textMuted;
        if (monto > 0) {
          bgColor = isHot
              ? AppTheme.colorDeudas.withAlpha((80 + 100 * intensity).toInt().clamp(0, 255))
              : AppTheme.primary.withAlpha((40 + 80 * intensity).toInt().clamp(0, 255));
          textColor = isHot ? Colors.white : AppTheme.primary;
        }
        if (isPico) {
          bgColor = AppTheme.colorGastos;
          textColor = Colors.white;
        }

        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: isPico ? Border.all(color: AppTheme.colorGastos, width: 2) : null,
          ),
          child: Center(
            child: Text(
              '$dia',
              style: TextStyle(fontSize: 10, fontWeight: isPico ? FontWeight.w900 : FontWeight.w600, color: textColor),
            ),
          ),
        );
      }),
    );
  }

  // ─── Interés Quemado ────────────────────────────────────────────────────────

  Widget _buildInteresQuemadoCard(Map<String, dynamic> data) {
    final double totalMes = (data['total_mensual'] as num?)?.toDouble() ?? 0.0;
    final double totalAnual = (data['total_anual'] as num?)?.toDouble() ?? 0.0;
    final double pctIngresos = (data['pct_de_ingresos'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> porBanco = data['por_banco'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.bgCard, AppTheme.colorGastos.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.colorGastos.withAlpha(60)),
        boxShadow: [BoxShadow(color: AppTheme.colorGastos.withAlpha(15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.colorGastos.withAlpha(25), shape: BoxShape.circle),
                child: const Icon(Icons.local_fire_department_rounded, color: AppTheme.colorGastos, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Dinero regalado al banco este mes:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCOP(totalMes), style: AppTheme.monoStyle(color: AppTheme.colorGastos, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ mes', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildBadge('${formatCOP(totalAnual)} / año', AppTheme.colorGastos),
              const SizedBox(width: 8),
              _buildBadge('${pctIngresos.toStringAsFixed(1)}% de tus ingresos', AppTheme.colorDeudas),
            ],
          ),
          if (porBanco.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderLight, height: 1),
            const SizedBox(height: 14),
            ...porBanco.take(3).map((b) {
              final banco = b['banco'] as String? ?? '';
              final interesMes = (b['interes_mes'] as num?)?.toDouble() ?? 0.0;
              final saldo = (b['saldo'] as num?)?.toDouble() ?? 0.0;
              final color = hexToColor(b['color'] as String? ?? '#9CA3AF');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(banco, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        Text('Saldo: ${formatCOP(saldo)}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      ],
                    )),
                    Text(formatCOP(interesMes), style: AppTheme.monoStyle(color: AppTheme.colorGastos, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── Días de Esclavitud Financiera ─────────────────────────────────────────

  Widget _buildEsclavitudFinancieraCard(Map<String, dynamic> data) {
    final double diasComprometidos = (data['dias_comprometidos'] as num?)?.toDouble() ?? 0.0;
    final double diasLibres = (data['dias_libres'] as num?)?.toDouble() ?? 0.0;
    final double diasCuotas = (data['dias_en_cuotas_tarjeta'] as num?)?.toDouble() ?? 0.0;
    final double diasGastos = (data['dias_en_gastos_fijos'] as num?)?.toDouble() ?? 0.0;
    final double pctLibertad = (data['pct_libertad'] as num?)?.toDouble() ?? 0.0;
    final double ingresoDiario = (data['ingreso_diario'] as num?)?.toDouble() ?? 0.0;

    Color libertadColor = AppTheme.secondary;
    if (pctLibertad < 30) libertadColor = AppTheme.colorGastos;
    else if (pctLibertad < 50) libertadColor = AppTheme.colorDeudas;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: libertadColor.withAlpha(25), shape: BoxShape.circle),
                child: Icon(Icons.hourglass_bottom_rounded, color: libertadColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Días de trabajo dedicados a obligaciones', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text('Ingreso diario: ${formatCOP(ingresoDiario)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Visualización de los 30 días
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${diasGastos.toStringAsFixed(1)} días', style: AppTheme.monoStyle(color: AppTheme.colorGastos, fontSize: 18, fontWeight: FontWeight.w800)),
                    const Text('en Gastos Fijos', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.borderLight),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${diasCuotas.toStringAsFixed(1)} días', style: AppTheme.monoStyle(color: AppTheme.colorDeudas, fontSize: 18, fontWeight: FontWeight.w800)),
                      const Text('en Cuotas TC', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barra visual de distribución
          _buildDiasBarra(diasGastos, diasCuotas, diasLibres),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${diasComprometidos.toStringAsFixed(1)} días ocupados', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              Text('${diasLibres.toStringAsFixed(1)} días LIBRES', style: TextStyle(color: libertadColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiasBarra(double diasGastos, double diasCuotas, double diasLibres) {
    final total = diasGastos + diasCuotas + diasLibres;
    if (total <= 0) return const SizedBox.shrink();
    final double pGastos = diasGastos / total;
    final double pCuotas = diasCuotas / total;
    final double pLibres = diasLibres / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            Flexible(flex: (pGastos * 100).toInt(), child: Container(color: AppTheme.colorGastos)),
            Flexible(flex: (pCuotas * 100).toInt(), child: Container(color: AppTheme.colorDeudas)),
            Flexible(flex: (pLibres * 100).toInt(), child: Container(color: AppTheme.secondary)),
          ],
        ),
      ),
    );
  }

  // ─── Dependencia por Tarjeta ────────────────────────────────────────────────

  Widget _buildDependenciaTarjetasCard(Map<String, dynamic> data) {
    final List<dynamic> lista = data['lista'] as List<dynamic>? ?? [];
    final double totalDeuda = (data['total_deuda'] as num?)?.toDouble() ?? 0.0;
    final double pctIngCuotas = (data['pct_ingresos_cuotas'] as num?)?.toDouble() ?? 0.0;

    Color riesgoColor = AppTheme.secondary;
    if (pctIngCuotas > 40) riesgoColor = AppTheme.colorGastos;
    else if (pctIngCuotas > 25) riesgoColor = AppTheme.colorDeudas;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.colorAhorros.withAlpha(25), shape: BoxShape.circle),
                  child: const Icon(Icons.credit_card_rounded, color: AppTheme.colorAhorros, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Carga por Banco', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
              ]),
              _buildBadge('${pctIngCuotas.toStringAsFixed(0)}% de ingresos', riesgoColor),
            ],
          ),
          const SizedBox(height: 6),
          Text('Deuda total activa: ${formatCOP(totalDeuda)}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No hay cuotas activas de tarjeta este mes.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            )
          else ...[
            const SizedBox(height: 16),
            ...lista.map((item) {
              final banco = item['banco'] as String? ?? '';
              final cuotaMes = (item['cuota_mes'] as num?)?.toDouble() ?? 0.0;
              final saldo = (item['saldo_total'] as num?)?.toDouble() ?? 0.0;
              final pctIngresos = (item['pct_ingresos'] as num?)?.toDouble() ?? 0.0;
              final pctDeuda = (item['pct_deuda_total'] as num?)?.toDouble() ?? 0.0;
              final color = hexToColor(item['color'] as String? ?? '#9CA3AF');
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(banco, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary))),
                        Text('Cuota: ${formatCOP(cuotaMes)}', style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (pctDeuda / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppTheme.borderLight,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${pctDeuda.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 2),
                    Text('Saldo: ${formatCOP(saldo)} — Cuota toma ${pctIngresos.toStringAsFixed(0)}% de tus ingresos',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── Eficiencia de Ahorro ───────────────────────────────────────────────────

  Widget _buildEficienciaAhorroCard(Map<String, dynamic> data) {
    final double superavit = (data['superavit_estimado'] as num?)?.toDouble() ?? 0.0;
    final double ahorroReal = (data['ahorro_real'] as num?)?.toDouble() ?? 0.0;
    final double tasa = (data['tasa_ahorro'] as num?)?.toDouble() ?? 0.0;
    final double ingresos = (data['ingresos'] as num?)?.toDouble() ?? 0.0;

    Color tasaColor = AppTheme.secondary;
    if (tasa < 10) tasaColor = AppTheme.colorGastos;
    else if (tasa < 20) tasaColor = AppTheme.colorDeudas;

    final String mensaje = tasa >= 20
        ? 'Excelente disciplina financiera. Sigue así.'
        : tasa >= 10
            ? 'Ahorro moderado. Intenta reducir gastos variables.'
            : 'Tasa de ahorro baja. Revisa tus gastos este mes.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.bgCard, tasaColor.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tasaColor.withAlpha(60)),
        boxShadow: [BoxShadow(color: tasaColor.withAlpha(15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: tasaColor.withAlpha(25), shape: BoxShape.circle),
                child: Icon(Icons.savings_rounded, color: tasaColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Tasa real de ahorro del mes', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
              Text('${tasa.toStringAsFixed(1)}%', style: AppTheme.monoStyle(color: tasaColor, fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (tasa / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppTheme.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(tasaColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricItem('Ingresos', formatCOP(ingresos), AppTheme.textPrimary)),
              Expanded(child: _buildMetricItem('Superávit estimado', formatCOP(superavit), AppTheme.primary)),
              Expanded(child: _buildMetricItem('Ahorro real', formatCOP(ahorroReal), tasaColor)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: tasaColor.withAlpha(15), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded, color: tasaColor, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(mensaje, style: TextStyle(color: tasaColor, fontSize: 11, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Endeudamiento ──────────────────────────────────────────────────────────

  Widget _buildEndeudamientoCard(double pct, String nivel, Map<String, dynamic> provider) {
    final color = AppTheme.colorPorRiesgo(nivel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Deuda vs Activos', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                child: Text(nivel == 'Bajo' ? 'Saludable' : 'Riesgo $nivel',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${pct.toStringAsFixed(1)}%', style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0%', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              Text('Riesgo ( >60% )', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
          const Divider(height: 28, color: AppTheme.borderLight),
          Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.secondary)),
                    const SizedBox(width: 6),
                    const Text('A Favor', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 4),
                  Text(formatCOP((provider['cuentas_por_cobrar'] as num?)?.toDouble() ?? 0.0),
                      style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              )),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.colorGastos)),
                    const SizedBox(width: 6),
                    const Text('Cuentas x Pagar', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 4),
                  Text(formatCOP((provider['deuda_tarjetas'] as num?)?.toDouble() ?? 0.0),
                      style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Resumen Cards ──────────────────────────────────────────────────────────

  Widget _buildResumenCards(double ingresos, double egresos) {
    return Row(
      children: [
        Expanded(child: _buildResumenCard('Ingresos', ingresos, Icons.arrow_upward_rounded, AppTheme.colorIngresos, '+12.5%', true)),
        const SizedBox(width: 12),
        Expanded(child: _buildResumenCard('Gastos', egresos, Icons.arrow_downward_rounded, AppTheme.colorGastos, '-2.4%', false)),
      ],
    );
  }

  Widget _buildResumenCard(String label, double monto, IconData icon, Color color, String pct, bool up) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(formatCOP(monto), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16))),
          const SizedBox(height: 6),
          Row(children: [
            Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: color, size: 12),
            const SizedBox(width: 2),
            Text(pct, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }

  // ─── Radar Hormiga ──────────────────────────────────────────────────────────

  Widget _buildRadarHormigaCard(Map<String, dynamic> radar) {
    final double anual = (radar['total_anual'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> lista = radar['lista'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bug_report_rounded, color: AppTheme.colorGastos, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('Fuga anual detectada: ${formatCOP(anual)} / año',
                style: const TextStyle(color: AppTheme.colorGastos, fontWeight: FontWeight.w700, fontSize: 13))),
          ]),
          const SizedBox(height: 14),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('¡Excelente! No hemos detectado suscripciones ni gastos hormiga recurrentes.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lista.length > 5 ? 5 : lista.length,
              separatorBuilder: (_, __) => const Divider(color: AppTheme.borderLight, height: 16),
              itemBuilder: (context, idx) {
                final item = lista[idx] as Map<String, dynamic>;
                final nombre = item['nombre'] as String? ?? '';
                final cant = item['cantidad'] as int? ?? 1;
                final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
                final an = (item['anualizado'] as num?)?.toDouble() ?? 0.0;
                return Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.colorDeudas)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nombre, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('$cant registro${cant > 1 ? 's' : ''} en este ciclo', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(formatCOP(tot), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${formatCOP(an)} / año', style: AppTheme.monoStyle(color: AppTheme.colorGastos, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── Flujo de Caja (Bar Chart) ──────────────────────────────────────────────

  Widget _buildBarChart(List<dynamic> data) {
    double maxY = 0;
    for (var d in data) {
      maxY = math.max(maxY, (d['ingresos'] as num).toDouble());
      maxY = math.max(maxY, (d['egresos'] as num).toDouble());
    }
    if (maxY == 0) maxY = 10000;

    return Container(
      height: 230,
      padding: const EdgeInsets.all(16).copyWith(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value != value.toInt() || value.toInt() < 0 || value.toInt() >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(data[value.toInt()]['label'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                );
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (val, meta) {
                if (val == 0) return const SizedBox.shrink();
                return Text('\$${(val / 1000).toStringAsFixed(0)}k', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9));
              },
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.borderLight, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(data.length, (i) {
            final double ingresos = (data[i]['ingresos'] as num).toDouble();
            final double egresos = (data[i]['egresos'] as num).toDouble();
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: ingresos, color: AppTheme.colorIngresos, width: 8, borderRadius: BorderRadius.circular(4)),
                BarChartRodData(toY: egresos, color: AppTheme.colorGastos, width: 8, borderRadius: BorderRadius.circular(4)),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ─── Simulador ──────────────────────────────────────────────────────────────

  Widget _buildSimuladorDeudaCard(Map<String, dynamic> sim) {
    final avalancha = sim['avalancha'] as Map<String, dynamic>?;
    final bola = sim['bola_nieve'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildSimuladorTab('Avalancha (Ahorro Interés)', _simuladorAvalancha, () {
                setState(() => _simuladorAvalancha = true);
              })),
              const SizedBox(width: 10),
              Expanded(child: _buildSimuladorTab('Bola de Nieve (Victoria Rápida)', !_simuladorAvalancha, () {
                setState(() => _simuladorAvalancha = false);
              })),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Simula un abono extra este mes:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSimuladorChip('\$100k', 100000.0),
                const SizedBox(width: 8),
                _buildSimuladorChip('\$200k', 200000.0),
                const SizedBox(width: 8),
                _buildSimuladorChip('\$500k', 500000.0),
                const SizedBox(width: 8),
                _buildSimuladorChip('\$1M', 1000000.0),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_simuladorAvalancha && avalancha != null)
            _buildSimuladorResultado(
              titulo: 'Recomendación Avalancha',
              subtitulo: 'Pagar a la deuda de mayor interés (${avalancha['top_deuda']['banco']})',
              destacado: 'Ahorro proyectado en intereses: ${formatCOP(avalancha['ahorro_estimado'])}',
              razon: avalancha['razon'] ?? '',
              color: AppTheme.colorDeudas,
            )
          else if (!_simuladorAvalancha && bola != null)
            _buildSimuladorResultado(
              titulo: 'Recomendación Bola de Nieve',
              subtitulo: 'Liquidar o reducir la menor deuda (${bola['top_deuda']['banco']})',
              destacado: 'Meses ganados: ¡${bola['meses_ganados']} cuotas antes de lo previsto!',
              razon: bola['razon'] ?? '',
              color: AppTheme.primary,
            )
          else
            const Text('No hay deudas de tarjeta activas para simular.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptySimulador() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderLight)),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppTheme.secondary, size: 24),
          SizedBox(width: 12),
          Expanded(child: Text('¡Excelente! No tienes compras de tarjeta con cuotas activas pendientes para simular abonos extra.',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.3))),
        ],
      ),
    );
  }

  Widget _buildSimuladorTab(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.borderLight, width: active ? 1.5 : 1),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: active ? AppTheme.primary : AppTheme.textSecondary, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 11)),
      ),
    );
  }

  Widget _buildSimuladorChip(String label, double val) {
    final active = _abonoSimulador == val;
    return InkWell(
      onTap: () => setState(() => _abonoSimulador = val),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.bgCanvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.borderLight),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSimuladorResultado({required String titulo, required String subtitulo, required String destacado, required String razon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withAlpha(60))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(subtitulo, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
            child: Text(destacado, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Text(razon, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  // ─── Camino a Cero Deuda ────────────────────────────────────────────────────

  Widget _buildAbonoExtraSlider(String mesLibre) {
    return StatefulBuilder(
      builder: (context, setStateSlider) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Abono Extra (% de Liquidez)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${_pctAbonoExtra.toInt()}%', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold)),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppTheme.secondary,
                  inactiveTrackColor: AppTheme.secondary.withAlpha(40),
                  thumbColor: AppTheme.secondary,
                  overlayColor: AppTheme.secondary.withAlpha(20),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _pctAbonoExtra,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (val) { setStateSlider(() => _pctAbonoExtra = val); },
                  onChangeEnd: (val) { 
                    setState(() { _pctAbonoExtra = val; }); 
                    ref.read(virtualAssistantProvider.notifier).analyzeChart('abono_extra', {'pct': val, 'mesLibre': mesLibre});
                  },
                ),
              ),
              const Text('Destina un porcentaje de tu dinero libre al pago acelerado de tus deudas para calcular cuándo terminarías de pagar.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineChart(List<dynamic> data, String mesLibre) {
    double maxY = 0;
    for (var d in data) {
      double deuda = (d['deuda_restante'] as num).toDouble();
      maxY = math.max(maxY, deuda);
    }
    if (maxY == 0) maxY = 10000;

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['deuda_restante'] as num).toDouble()));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Proyección estimada', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text('Libre de deuda: $mesLibre', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.1,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) => touchedSpots.map((spot) =>
                        LineTooltipItem(formatCOP(spot.y), const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    interval: math.max(1.0, (data.length / 6).floorToDouble()),
                    getTitlesWidget: (value, meta) {
                      if (value != value.toInt() || value.toInt() < 0 || value.toInt() >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(data[value.toInt()]['label'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      );
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (val, meta) =>
                        Text('\$${(val / 1000).toStringAsFixed(1)}k', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.borderLight, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.colorDeudas,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppTheme.colorDeudas.withAlpha(20)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Categorías ─────────────────────────────────────────────────────────────

  Widget _buildCategoriasCard() {
    if (_gastosDelMes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderLight)),
        child: const Center(child: Text('Sin gastos registrados para analizar este mes.', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    final Map<String, double> categorySums = {};
    final Map<String, String> categoryColors = {};
    double totalExpenses = 0.0;

    for (var item in _gastosDelMes) {
      final catName = item['categoria_nombre']?.toString() ?? 'Otros';
      final amount = (item['monto'] as num?)?.toDouble() ?? 0.0;
      final colorHex = item['categoria_color']?.toString() ?? '#9CA3AF';
      categorySums[catName] = (categorySums[catName] ?? 0.0) + amount;
      categoryColors[catName] = colorHex;
      totalExpenses += amount;
    }

    final sortedCategories = categorySums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final List<PieChartSectionData> sections = [];
    for (int i = 0; i < sortedCategories.length; i++) {
      final entry = sortedCategories[i];
      final color = hexToColor(categoryColors[entry.key]!);
      sections.add(PieChartSectionData(color: color, value: entry.value, radius: 18, showTitle: false));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(sections: sections, centerSpaceRadius: 64, sectionsSpace: 2, startDegreeOffset: -90)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Total', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(formatCOP(totalExpenses), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedCategories.length,
            separatorBuilder: (_, __) => const Divider(height: 18, color: AppTheme.borderLight),
            itemBuilder: (context, index) {
              final entry = sortedCategories[index];
              final color = hexToColor(categoryColors[entry.key]!);
              final pct = totalExpenses > 0 ? (entry.value / totalExpenses * 100) : 0.0;
              return Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.key, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
                  Text(formatCOP(entry.value), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 14),
                  SizedBox(width: 36, child: Text('${pct.toStringAsFixed(0)}%',
                      textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  // ─── Hoja de Personalización de Módulos ────────────────────────────────────

  void _showCustomizeSheet(BuildContext context, AnalyticsProfileState profileState) {
    final perfil = profileState.perfilActivo;
    final Set<String> selected = Set<String>.from(perfil.modulos);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Personalizar Vista', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
                            Text('Perfil: ${perfil.nombre}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ]),
                          TextButton(
                            onPressed: () {
                              ref.read(analyticsProfileProvider.notifier).actualizarModulos(perfil.id, selected.toList());
                              Navigator.pop(context);
                            },
                            child: const Text('Guardar', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 16),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: AnalyticsModuleIds.labels.entries.map((entry) {
                          final isActive = selected.contains(entry.key);
                          final emoji = AnalyticsModuleIds.icons[entry.key] ?? '📊';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.primary.withAlpha(10) : AppTheme.bgCanvas,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isActive ? AppTheme.primary.withAlpha(80) : AppTheme.borderLight, width: isActive ? 1.5 : 1),
                            ),
                            child: ListTile(
                              leading: Text(emoji, style: const TextStyle(fontSize: 22)),
                              title: Text(entry.value, style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13,
                                color: isActive ? AppTheme.primary : AppTheme.textPrimary,
                              )),
                              trailing: Switch.adaptive(
                                value: isActive,
                                activeTrackColor: AppTheme.primary,
                                onChanged: (val) => setModal(() {
                                  if (val) { selected.add(entry.key); } else { selected.remove(entry.key); }
                                }),
                              ),
                              onTap: () => setModal(() {
                                if (isActive) selected.remove(entry.key); else selected.add(entry.key);
                              }),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Hoja de Gestión de Perfiles ───────────────────────────────────────────

  void _showManageProfilesSheet(BuildContext context, AnalyticsProfileState profileState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(analyticsProfileProvider);
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gestionar Perfiles', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary)),
                          TextButton.icon(
                            onPressed: () => _showCreateProfileDialog(context),
                            icon: const Icon(Icons.add_rounded, size: 18, color: AppTheme.primary),
                            label: const Text('Nuevo', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 16),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: state.perfiles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final p = state.perfiles[idx];
                          final isActivo = p.id == state.perfilActivoId;
                          return Container(
                            decoration: BoxDecoration(
                              color: isActivo ? AppTheme.primary.withAlpha(12) : AppTheme.bgCanvas,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isActivo ? AppTheme.primary : AppTheme.borderLight, width: isActivo ? 1.5 : 1),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: isActivo ? AppTheme.primary : AppTheme.bgCardLight,
                                child: Text('${idx + 1}', style: TextStyle(color: isActivo ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              title: Text(p.nombre, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isActivo ? AppTheme.primary : AppTheme.textPrimary)),
                              subtitle: Text('${p.modulos.length} módulos activos${p.esPorDefecto ? ' · Por defecto' : ''}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                color: AppTheme.bgCard,
                                onSelected: (action) async {
                                  final notifier = ref.read(analyticsProfileProvider.notifier);
                                  if (action == 'select') {
                                    notifier.seleccionarPerfil(p.id);
                                  } else if (action == 'default') {
                                    await notifier.setPerfilPorDefecto(p.id);
                                  } else if (action == 'rename') {
                                    if (context.mounted) _showRenameDialog(context, p.id, p.nombre);
                                  } else if (action == 'delete') {
                                    if (state.perfiles.length > 1) {
                                      await notifier.eliminarPerfil(p.id);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (!isActivo) const PopupMenuItem(value: 'select', child: Text('Activar este perfil')),
                                  if (!p.esPorDefecto) const PopupMenuItem(value: 'default', child: Text('Marcar como predeterminado')),
                                  const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                                  if (state.perfiles.length > 1)
                                    const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: AppTheme.colorGastos))),
                                ],
                              ),
                              onTap: () => ref.read(analyticsProfileProvider.notifier).seleccionarPerfil(p.id),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton(
                        onPressed: () => ref.read(analyticsProfileProvider.notifier).restaurarPredeterminados(),
                        child: const Text('Restaurar perfiles predeterminados', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreateProfileDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nuevo Perfil', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del perfil', hintText: 'Ej: Mi Vista Favorita'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final nombre = controller.text.trim();
              if (nombre.isNotEmpty) {
                await ref.read(analyticsProfileProvider.notifier).crearPerfil(nombre, AnalyticsModuleIds.allIds);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String id, String nombreActual) {
    final controller = TextEditingController(text: nombreActual);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Renombrar Perfil', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final nombre = controller.text.trim();
              if (nombre.isNotEmpty) {
                await ref.read(analyticsProfileProvider.notifier).actualizarNombre(id, nombre);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ─── Section Title ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.2),
    );
  }
}
