class SupabaseConfig {
  // Replace these with your actual Supabase project URL and anon key
  static const String supabaseUrl = 'https://hofrgrynbbusnclbslpl.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhvZnJncnluYmJ1c25jbGJzbHBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMjA4MDQsImV4cCI6MjA3OTg5NjgwNH0.4seLOzHCmg-SyzIuinfOEYwj7MH0a3FweDGyKw_8U9I';

  // Storage bucket names (only needed for image storage)
  static const String profilePicturesBucket = 'profile_pictures';
  static const String documentsBucket = 'documents';
}
