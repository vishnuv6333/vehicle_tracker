import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/vehicle_status.dart';
import '../../bloc/vehicle_detail_bloc.dart';
import '../../bloc/vehicle_detail_state.dart';
import '../../bloc/vehicle_detail_event.dart';
import '../../data/database_service.dart';
import '../../models/signal_reading.dart';

class VehicleDetailScreen extends StatelessWidget {
  final VehicleStatus vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VehicleDetailBloc(DatabaseService())
        ..add(LoadVehicleDetail(vehicle.id)),
      child: Scaffold(
        appBar: AppBar(
          title: Text('${vehicle.regNumber} Details'),
        ),
        body: BlocBuilder<VehicleDetailBloc, VehicleDetailState>(
          builder: (context, state) {
            if (state.isLoading && state.readings.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(child: Text('Error: ${state.error}'));
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Readings Register',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final reading = state.readings[index];
                      return _ReadingTile(reading: reading);
                    },
                    childCount: state.readings.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('SOC History',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                if (state.socHistory.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 250,
                      // padding: const EdgeInsets.only(right: 16, left: 8, bottom: 16),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true, reservedSize: 40)),
                            bottomTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: state.socHistory.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(),
                                    e.value['value'] as double);
                              }).toList(),
                              isCurved: true,
                              color: Colors.deepPurple,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.deepPurple.withOpacity(0.3)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (state.socHistory.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No SOC history available.'),
                    ),
                  )
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final SignalReading reading;

  const _ReadingTile({required this.reading});

  @override
  Widget build(BuildContext context) {
    Color pillColor;
    String pillText;

    switch (reading.verdict) {
      case Verdict.NORMAL:
        pillColor = Colors.green;
        pillText = 'NORMAL';
        break;
      case Verdict.ALERT:
        pillColor = Colors.red;
        pillText = 'ALERT';
        break;
      case Verdict.STALE:
        pillColor = Colors.grey;
        pillText = 'STALE';
        break;
      case Verdict.NONE:
      default:
        pillColor = Colors.transparent;
        pillText = '';
        break;
    }

    final valueText = reading.value != null
        ? '${reading.value!.toStringAsFixed(1)} ${reading.unit}'
        : '—';
    final ageText =
        reading.verdict != Verdict.NONE ? '${reading.age.inMinutes}m ago' : '';

    return ListTile(
      title: Text(reading.label),
      subtitle: Text(ageText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(valueText,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (reading.verdict != Verdict.NONE) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: pillColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pillColor.withOpacity(0.5)),
              ),
              child: Text(
                pillText,
                style: TextStyle(
                    color: pillColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
