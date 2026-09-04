import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/geofence_bloc.dart';
import '../../bloc/geofence_state.dart';
import '../../bloc/geofence_event.dart';
import '../../data/database_service.dart';

class GeofencesScreen extends StatelessWidget {
  const GeofencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          GeofenceBloc(DatabaseService())..add(LoadGeofences()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Geofences'),
          actions: [
            // Builder(builder: (ctx) {
            //   return IconButton(
            //     icon: const Icon(Icons.calculate),
            //     tooltip: 'Recalculate Trips',
            //     onPressed: () {
            //       ctx.read<GeofenceBloc>().add(RecalculateAllTrips());
            //       ScaffoldMessenger.of(ctx).showSnackBar(
            //         const SnackBar(content: Text('Recalculating trips...')),
            //       );
            //     },
            //   );
            // }),
          ],
        ),
        body: BlocBuilder<GeofenceBloc, GeofenceState>(
          builder: (context, state) {
            if (state.isLoading && state.geofences.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(child: Text('Error: ${state.error}'));
            }

            if (state.geofences.isEmpty) {
              return const Center(child: Text('No geofences found.'));
            }

            return ListView.builder(
              itemCount: state.geofences.length,
              itemBuilder: (context, index) {
                final gf = state.geofences[index];
                final count = state.activeVehicleCounts[gf.id] ?? 0;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(gf.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Lat: ${gf.lat}, Lng: ${gf.lng}\nRadius: ${gf.radius}m\nLive Count: $count vehicles'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _showEditGeofenceDialog(context, gf);
                          },
                        ),
                        Switch(
                          value: gf.active,
                          onChanged: (val) {
                            context
                                .read<GeofenceBloc>()
                                .add(ToggleGeofence(gf.id, val));
                          },
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: Builder(builder: (context) {
          return FloatingActionButton(
            onPressed: () {
              _showAddGeofenceDialog(context);
            },
            child: const Icon(Icons.add),
          );
        }),
      ),
    );
  }

  void _showAddGeofenceDialog(BuildContext context) {
    final bloc = context.read<GeofenceBloc>();
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final radCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Geofence'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: latCtrl,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: lngCtrl,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: radCtrl,
                  decoration: const InputDecoration(labelText: 'Radius (m)'),
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL')),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text;
                final lat = double.tryParse(latCtrl.text) ?? 0.0;
                final lng = double.tryParse(lngCtrl.text) ?? 0.0;
                final rad = double.tryParse(radCtrl.text) ?? 0.0;
                bloc.add(AddGeofence(name, lat, lng, rad));
                Navigator.pop(ctx);
              },
              child: const Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  void _showEditGeofenceDialog(BuildContext context, dynamic gf) {
    final bloc = context.read<GeofenceBloc>();
    final nameCtrl = TextEditingController(text: gf.name);
    final latCtrl = TextEditingController(text: gf.lat.toString());
    final lngCtrl = TextEditingController(text: gf.lng.toString());
    final radCtrl = TextEditingController(text: gf.radius.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Geofence'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: latCtrl,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: lngCtrl,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: radCtrl,
                  decoration: const InputDecoration(labelText: 'Radius (m)'),
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL')),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text;
                final lat = double.tryParse(latCtrl.text) ?? 0.0;
                final lng = double.tryParse(lngCtrl.text) ?? 0.0;
                final rad = double.tryParse(radCtrl.text) ?? 0.0;
                bloc.add(EditGeofence(gf.id, name, lat, lng, rad));
                Navigator.pop(ctx);
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }
}
