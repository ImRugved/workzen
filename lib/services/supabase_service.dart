import 'dart:typed_data';
import 'package:workzen/constants/firestore_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/supabase_config.dart';

/// Supabase is used only to store profile pictures (bucket
/// [SupabaseConfig.profilePicturesBucket]). Everything else lives in Firebase.
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
