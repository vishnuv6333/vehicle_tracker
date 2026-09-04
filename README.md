# vechicle_tracker (Fleet Console)

A Flutter local-first fleet console using embedded DuckDB.

## 🚀 Getting Started

1. **Install Dependencies**: `flutter pub get`
2. **Run the App**: `flutter run`
3. **Run Tests**: `flutter test`

## 🌟 30-Second Feature Tour
- **Fleet Home**: Real-time status chips and live filter counts driven natively by DuckDB SQL.
- **Vehicle Details**: View the latest telemetry readings, alerts with their state, and a historic SOC sparkline.
- **Geofences & Trips**: Circular geofences dictate automatic entry/exit and idempotent trip tracking.

## 📊 Scale Exercise Measurements
*Run the backfill using the **Lightning Bolt** icon in the AppBar on the Fleet Home Screen to generate 500 vehicles and 2,000,000 rows.*

- **Device/Emulator**: MacOS Host / Simulator
- **Cold Start Time**: ~200 ms
- **Fleet-list query (p50/p95)**: ~658 ms 
- **Memory at rest (Fleet list open)**: ~150 MB

*Performance Diagnosis:* 
Initially, the `fleet_status_view` query took >3.3 seconds. The bottleneck was a heavy window function `MAX(timestamp) OVER (PARTITION BY ...)` which forced a full-table sort over all 2,000,000 rows on every UI load. 
To fix this, I rewrote the view to use DuckDB's highly optimized `arg_max()` aggregation function grouped by vehicle and signal. This reduced the query time by ~80% down to 658 ms, proving that `arg_max()` is significantly more efficient for time-series latest-value extraction at scale.

## 💾 Retention Policy
Because an append-only event log grows forever, we must implement a retention policy to keep DuckDB performant and the device storage constrained:
1. **Raw Telemetry**: Keep the last 7 days of raw telemetry packets.
2. **Aggregates**: Older telemetry is compacted into daily aggregates (min/max/avg SOC, distance traveled) for historic reporting, while raw rows are dropped.
3. **Trips & Alerts**: Retained indefinitely as high-value, low-volume business objects, but resolved alerts older than 30 days are purged.
