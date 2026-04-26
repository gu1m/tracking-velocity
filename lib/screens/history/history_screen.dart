import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/trip.dart';
import '../../services/storage_service.dart';
import '../../services/export_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/trip_card.dart';
import 'trip_detail_screen.dart';
import 'search_filter_screen.dart';

/// Lista de viagens com busca rápida + acesso ao filtro avançado
/// e à exportação dos resultados em Excel.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _quickQuery = '';
  TripFilter _filter = const TripFilter();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final results = storage.search(
      from: _filter.from,
      to: _filter.to,
      locationQuery: _quickQuery.isNotEmpty ? _quickQuery : _filter.location,
      minSpeedKmh: _filter.minSpeedKmh,
      maxSpeedKmh: _filter.maxSpeedKmh,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          IconButton(
            tooltip: 'Filtros avançados',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _quickQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar por endereço, cidade…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _quickQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _quickQuery = ''),
                      )
                    : null,
              ),
            ),
          ),
          if (_filter.hasActiveFilter) _activeFilterBar(),
          Expanded(
            child: results.isEmpty
                ? _emptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      _SummaryHeader(count: results.length),
                      const SizedBox(height: 12),
                      ...results.map((t) => TripCard(
                            trip: t,
                            onTap: () => _openTrip(t),
                          )),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: results.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed:
                  _exporting ? null : () => _exportResults(results),
              backgroundColor: AppColors.accent,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_rounded),
              label: Text(_exporting ? 'Gerando…' : 'Exportar Excel'),
            ),
    );
  }

  Widget _activeFilterBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              color: AppColors.primaryDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _filter.describe(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: () => setState(() => _filter = const TripFilter()),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.divider,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 56, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhuma viagem encontrada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tente ajustar os filtros ou buscar por outro endereço.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTrip(Trip trip) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
    );
  }

  Future<void> _openFilter() async {
    final result = await Navigator.of(context).push<TripFilter>(
      MaterialPageRoute(
        builder: (_) => SearchFilterScreen(initial: _filter),
      ),
    );
    if (result != null) setState(() => _filter = result);
  }

  Future<void> _exportResults(List<Trip> trips) async {
    setState(() => _exporting = true);
    try {
      await ExportService().exportTrips(
        trips,
        filterDescription: _filter.hasActiveFilter
            ? _filter.describe()
            : (_quickQuery.isNotEmpty ? 'Busca: $_quickQuery' : null),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relatório gerado com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _SummaryHeader extends StatelessWidget {
  final int count;
  const _SummaryHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.list_alt_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$count viagem${count == 1 ? '' : 's'} encontrada${count == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
