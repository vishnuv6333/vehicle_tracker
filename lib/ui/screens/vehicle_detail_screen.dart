import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/vehicle_status.dart';
import '../../bloc/vehicle_detail_bloc.dart';
import '../../bloc/vehicle_detail_state.dart';
import '../../bloc/vehicle_detail_event.dart';
import '../../data/database_service.dart';
import '../../models/signal_reading.dart';
import 'trip_detail_screen.dart';

class VehicleDetailScreen extends StatelessWidget {
  final VehicleStatus vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VehicleDetailBloc(DatabaseService())
        ..add(LoadVehicleDetail(vehicle.id)),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text('${vehicle.regNumber} Details'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Trips'),
              ],
            ),
          ),
          body: Builder(
            builder: (ctx) {
              final tabCtrl = DefaultTabController.of(ctx);
              tabCtrl.addListener(() {
                if (tabCtrl.indexIsChanging && tabCtrl.index == 1) {
                  ctx.read<VehicleDetailBloc>().add(RecalculateVehicleTrips(vehicle.id));
                }
              });

              return BlocBuilder<VehicleDetailBloc, VehicleDetailState>(
                builder: (context, state) {
                  if (state.isLoading && state.readings.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
              if (state.error != null) {
                return Center(child: Text('Error: ${state.error}'));
              }

              return TabBarView(
                children: [
                  _buildOverviewTab(context, state),
                  _buildTripsTab(context, state),
                ],
              );
            },
          );
        },
      ),
    ),
  ),
);
  }

  Widget _buildOverviewTab(BuildContext context, VehicleDetailState state) {
    return CustomScrollView(
      slivers: [
        if (state.activeAlerts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Alerts',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.red)),
                  const SizedBox(height: 8),
                  ...state.activeAlerts
                      .where((a) => a['status'] == 'active')
                      .map((alert) {
                    return Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        leading: Icon(Icons.warning,
                            color: alert['severity'] == 'Critical'
                                ? Colors.red
                                : Colors.orange),
                        title: Text(
                            '${alert['alert_type'].toString().toUpperCase()} - ${alert['severity']}'),
                        trailing: TextButton(
                          onPressed: () {
                            _showDismissalSheet(context, alert['id']);
                          },
                          child: const Text('DISMISS'),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
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
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: state.socHistory.asMap().entries.map((e) {
                        return FlSpot(
                            e.key.toDouble(), e.value['value'] as double);
                      }).toList(),
                      isCurved: true,
                      color: Colors.deepPurple,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                          show: true,
                          color: Colors.deepPurple.withValues(alpha: 0.3)),
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
  }

  Widget _buildTripsTab(BuildContext context, VehicleDetailState state) {
    if (state.trips.isEmpty) {
      return const Center(child: Text('No trips found for this vehicle.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: state.trips.length,
      itemBuilder: (context, index) {
        final trip = state.trips[index];
        return TripTimelineWidget(trip: trip);
      },
    );
  }
}

void _showDismissalSheet(BuildContext context, String alertId) {
  final bloc = context.read<VehicleDetailBloc>();
  showModalBottomSheet(
    context: context,
    builder: (_) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
                title: Text('Dismiss Reason',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            ListTile(
              title: const Text('I am on it'),
              onTap: () {
                Navigator.pop(context);
                _dismiss(context, bloc, alertId, 'I am on it');
              },
            ),
            ListTile(
              title: const Text('Wrong alert'),
              onTap: () {
                Navigator.pop(context);
                _dismiss(context, bloc, alertId, 'Wrong alert');
              },
            ),
            ListTile(
              title: const Text('Something else…'),
              onTap: () {
                Navigator.pop(context);
                _dismiss(context, bloc, alertId, 'Something else…');
              },
            ),
          ],
        ),
      );
    },
  );
}

void _dismiss(BuildContext context, VehicleDetailBloc bloc, String alertId,
    String reason) {
  bloc.add(DismissAlert(alertId, reason));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Alert dismissed'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          bloc.add(UndoDismissAlert(alertId));
        },
      ),
    ),
  );
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
                color: pillColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pillColor.withValues(alpha: 0.5)),
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

class TripTimelineWidget extends StatelessWidget {
  final Map<String, dynamic> trip;

  const TripTimelineWidget({super.key, required this.trip});

  String _formatTime(DateTime dt) {
    int hour = dt.hour;
    final int minute = dt.minute;
    final String ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final origin = trip['origin_geofence_name'] ?? 'Unknown Geofence';
    final destination = trip['destination_geofence_name'] ?? 'Unknown Geofence';
    final startTime = trip['start_time'] as DateTime;
    final endTime = trip['end_time'] as DateTime?;
    final isCompleted = trip['status'] == 'COMPLETED';

    return InkWell(
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)));
        },
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(origin,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11.0, top: 4, bottom: 4),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: Colors.grey.shade300,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Row(
                    children: [
                      const Text('EXIT',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_downward,
                          color: Colors.grey.shade400, size: 16),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11.0, top: 4, bottom: 4),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: Colors.grey.shade300,
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.deepPurple),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11.0, top: 4, bottom: 4),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: Colors.grey.shade300,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Row(
                    children: [
                      const Text('ENTRY',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_downward,
                          color: Colors.grey.shade400, size: 16),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11.0, top: 4, bottom: 4),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: Colors.grey.shade300,
                  ),
                ),
                Row(
                  children: [
                    Icon(isCompleted ? Icons.flag : Icons.run_circle_outlined,
                        color: isCompleted ? Colors.green : Colors.orange),
                    const SizedBox(width: 8),
                    Text(isCompleted ? destination : 'IN PROGRESS',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isCompleted ? Colors.black : Colors.orange)),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Started: ${_formatTime(startTime)}',
                        style: const TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.w500)),
                    if (endTime != null)
                      Text('Ended: ${_formatTime(endTime)}',
                          style: const TextStyle(
                              color: Colors.grey, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ));
  }
}
