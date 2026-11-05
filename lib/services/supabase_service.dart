import 'dart:typed_data';
import 'package:workzen/constants/firestore_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/supabase_config.dart';

/// Supabase is used only to store pictures: profile pictures (bucket
/// [SupabaseConfig.profilePicturesBucket]) and announcement pictures (bucket
/// [SupabaseConfig.announcementsBucket]). Everything else lives in Firebase.
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Uploads [imageBytes] as the user's profile picture, saves its public URL
  /// on the user's document and returns it.
  static Future<String> uploadProfileImage(
    String userId,
    Uint8List imageBytes,
  ) async {
    final fileName = 'profile_$userId.jpg';
    final bucket = _client.storage.from(SupabaseConfig.profilePicturesBucket);

    await bucket.uploadBinary(
      fileName,
      imageBytes,
      fileOptions: const FileOptions(
        upsert: true, // the same file name is replaced by the new picture
        contentType: 'image/jpeg',
      ),
    );

    // The file name never changes, so the plain URL would stay the same after
    // a new upload and both the app's image cache and Supabase's CDN would keep
    // showing the old picture. A changing query value makes it a new URL.
    final imageUrl =
        '${bucket.getPublicUrl(fileName)}?v=${DateTime.now().millisecondsSinceEpoch}';

    // Store the image URL in Firebase Firestore users table
    await _updateUserProfileImageUrl(userId, imageUrl);

    return imageUrl;
  }

  /// Uploads the picture of an announcement and returns its public URL. Each
  /// announcement has its own file (named after its id), so nothing is replaced.
  static Future<String> uploadAnnouncementImage(
    String announcementId,
    Uint8List imageBytes,
  ) async {
    final fileName = 'announcement_$announcementId.jpg';
    final bucket = _client.storage.from(SupabaseConfig.announcementsBucket);

    await bucket.uploadBinary(
      fileName,
      imageBytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    return bucket.getPublicUrl(fileName);
  }

  /// Uploads the picture of a newsletter post (same bucket as announcements,
  /// file named after the post) and returns its public URL.
  static Future<String> uploadNewsletterImage(
    String postId,
    Uint8List imageBytes,
  ) async {
    final fileName = 'newsletter_$postId.jpg';
    final bucket = _client.storage.from(SupabaseConfig.announcementsBucket);

    await bucket.uploadBinary(
      fileName,
      imageBytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    return bucket.getPublicUrl(fileName);
  }

  // Private method to update user profile image URL in Firebase Firestore
  static Future<void> _updateUserProfileImageUrl(
    String userId,
    String imageUrl,
  ) async {
    await _firestore.collection(FirestoreCollections.users).doc(userId).update({
      'profileImageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
