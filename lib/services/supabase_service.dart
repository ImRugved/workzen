import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Image upload to Supabase storage
  static Future<String> uploadProfileImage(String userId, Uint8List imageBytes) async {
    final fileName = 'profile_$userId.jpg';
    
    await _client.storage
        .from(SupabaseConfig.profilePicturesBucket)
        .uploadBinary(fileName, imageBytes, 
          fileOptions: const FileOptions(
            upsert: true, // Allow overwriting existing files
          ),
        );
    
    final imageUrl = _client.storage
        .from(SupabaseConfig.profilePicturesBucket)
        .getPublicUrl(fileName);
    
    // Store the image URL in Firebase Firestore users table
    await _updateUserProfileImageUrl(userId, imageUrl);
    
    return imageUrl;
  }
  
  // Upload document to Supabase storage
  static Future<String> uploadDocument(String userId, String fileName, Uint8List fileBytes) async {
    final uniqueFileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    
    await _client.storage
        .from(SupabaseConfig.documentsBucket)
        .uploadBinary(uniqueFileName, fileBytes);
    
    return _client.storage
        .from(SupabaseConfig.documentsBucket)
        .getPublicUrl(uniqueFileName);
  }
  
  // Delete file from Supabase storage
  static Future<void> deleteFile(String bucketName, String fileName) async {
    await _client.storage
        .from(bucketName)
        .remove([fileName]);
  }
  
  // Private method to update user profile image URL in Firebase Firestore
  static Future<void> _updateUserProfileImageUrl(String userId, String imageUrl) async {
    await _firestore.collection('users').doc(userId).update({
      'profileImageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}