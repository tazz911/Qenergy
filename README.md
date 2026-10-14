# EnergyIQ — AI-Based Smart Energy Monitoring and Anomaly Detection System

Flutter app + Supabase (PostgreSQL) database.

## Set up on a new PC
1. Install Flutter and Git.
2. `git clone https://github.com/tazz911/Qenergy.git`
3. `cd` into the project folder, then `flutter pub get`
4. `flutter run`

The app connects to the shared Supabase project (see `lib/core/config/supabase_config.dart`),
so every PC sees the same data.

## Database
- Schema: `supabase/schema.sql` (tables: profiles, zones, devices, energy_readings, alerts).
- `supabase/002_app_features.sql`: settings columns + chart functions (run after schema.sql; safe to re-run).
- To rebuild: Supabase → SQL Editor → paste `schema.sql` → Run (**deletes all data**), then `002_app_features.sql`.
- Meters send readings by calling `POST /rest/v1/rpc/ingest_reading` with their serial number and `api_key`.

## Test without hardware
`python tools/meter_simulator.py --device SERIAL:API_KEY` (serial + key are shown when you tap a device in the app).

Never commit the Supabase secret / service_role key or the database password.
