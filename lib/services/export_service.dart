import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trip.dart';

/// Serviço de exportação de relatórios em Excel.
///
/// O relatório é a peça-chave do app: o usuário usa esse arquivo como
/// prova documental ao recorrer de uma multa de velocidade.
///
/// Formato do relatório:
///  - Aba "Resumo": dados gerais da viagem (data, origem, destino,
///    velocidade média, máxima, distância, duração).
///  - Aba "Registros minuto a minuto": cada linha é a velocidade média
///    em um minuto, com timestamp, lat/long, endereço e precisão GPS.
class ExportService {
  static const _dateFormat = 'dd/MM/yyyy HH:mm:ss';

  /// Exporta uma única viagem como Excel e abre o share sheet.
  Future<File> exportTrip(Trip trip) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _buildSummarySheet(excel, [trip]);
    _buildRecordsSheet(excel, [trip]);

    return _saveAndShare(
      excel,
      filename:
          'relatorio_velocidade_${DateFormat('yyyyMMdd_HHmm').format(trip.startedAt)}.xlsx',
    );
  }

  /// Exporta um conjunto de viagens (resultado de filtro) em um único
  /// arquivo Excel.
  Future<File> exportTrips(
    List<Trip> trips, {
    String? filterDescription,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _buildSummarySheet(excel, trips, filterDescription: filterDescription);
    _buildRecordsSheet(excel, trips);

    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return _saveAndShare(
      excel,
      filename: 'relatorio_velocidade_${trips.length}_viagens_$stamp.xlsx',
    );
  }

  // ---------------------------------------------------------------
  // Aba "Resumo"
  void _buildSummarySheet(
    Excel excel,
    List<Trip> trips, {
    String? filterDescription,
  }) {
    final sheet = excel['Resumo'];
    final df = DateFormat(_dateFormat);

    // Cabeçalho do documento
    sheet.appendRow([
      TextCellValue('RELATÓRIO DE VELOCIDADE — Tracking Velocidade'),
    ]);
    sheet.appendRow([
      TextCellValue('Gerado em: ${df.format(DateTime.now())}'),
    ]);
    if (filterDescription != null) {
      sheet.appendRow([TextCellValue('Filtro aplicado: $filterDescription')]);
    }
    sheet.appendRow([TextCellValue('')]);

    // Cabeçalho da tabela
    final headers = [
      'ID Viagem',
      'Data início',
      'Data fim',
      'Origem',
      'Destino',
      'Velocidade média (km/h)',
      'Velocidade máxima (km/h)',
      'Distância (km)',
      'Duração (min)',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final t in trips) {
      sheet.appendRow([
        TextCellValue(t.id),
        TextCellValue(df.format(t.startedAt)),
        TextCellValue(t.endedAt != null ? df.format(t.endedAt!) : '-'),
        TextCellValue(t.startAddress),
        TextCellValue(t.endAddress ?? '-'),
        DoubleCellValue(t.avgSpeedKmh),
        DoubleCellValue(t.maxSpeedKmh),
        DoubleCellValue(t.distanceKm),
        IntCellValue(t.duration.inMinutes),
      ]);
    }

    // Largura das colunas (ajuste fino p/ leitura)
    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 38);
    sheet.setColumnWidth(4, 38);
    sheet.setColumnWidth(5, 22);
    sheet.setColumnWidth(6, 22);
    sheet.setColumnWidth(7, 14);
    sheet.setColumnWidth(8, 14);
  }

  // Aba "Registros minuto a minuto"
  void _buildRecordsSheet(Excel excel, List<Trip> trips) {
    final sheet = excel['Registros'];
    final df = DateFormat(_dateFormat);

    final headers = [
      'ID Viagem',
      'Data/Hora',
      'Velocidade média no minuto (km/h)',
      'Velocidade máxima no minuto (km/h)',
      'Latitude',
      'Longitude',
      'Precisão GPS (m)',
      'Endereço',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final t in trips) {
      for (final r in t.records) {
        sheet.appendRow([
          TextCellValue(t.id),
          TextCellValue(df.format(r.timestamp)),
          DoubleCellValue(r.speedKmh),
          DoubleCellValue(r.maxSpeedKmh),
          DoubleCellValue(r.latitude),
          DoubleCellValue(r.longitude),
          DoubleCellValue(r.accuracy),
          TextCellValue(r.address ?? '-'),
        ]);
      }
    }

    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 28);
    sheet.setColumnWidth(3, 28);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 14);
    sheet.setColumnWidth(6, 14);
    sheet.setColumnWidth(7, 38);
  }

  Future<File> _saveAndShare(Excel excel, {required String filename}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Não foi possível gerar o arquivo Excel.');
    }
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'Relatório de velocidade — Tracking Velocidade',
      text:
          'Segue o relatório com os dados de GPS para uso como prova documental.',
    );

    return file;
  }
}
