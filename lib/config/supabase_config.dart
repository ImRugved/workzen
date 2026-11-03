class SupabaseConfig {
  // Supabase project URL and anon key. The anon key is meant to be public (it
  // ships inside the app); what protects the data is the Storage policy on the
  // bucket below, set in the Supabase dashboard.
  static const String supabaseUrl = 'https://hofrgrynbbusnclbslpl.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhvZnJncnluYmJ1c25jbGJzbHBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMjA4MDQsImV4cCI6MjA3OTg5NjgwNH0.4seLOzHCmg-SyzIuinfOEYwj7MH0a3FweDGyKw_8U9I';

  // The only storage bucket the app uses
  static const String profilePicturesBucket = 'profile_pictures';
}
