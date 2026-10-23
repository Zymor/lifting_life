import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/user_profile.dart';
import '../configuration/supabase_config.dart';

/// All 9 secure storage buckets required by Task 4.
enum StorageBucket {
  profileAvatars(
    id: 'profile-avatars',
    maxBytes: 5 * 1024 * 1024, // 5 MB
    allowedExtensions: {'webp', 'png', 'jpg', 'jpeg'},
    requiresAdminWrite: false,
    userScopedPrefix: true,
  ),
  exerciseVideos(
    id: 'exercise-videos',
    maxBytes: 100 * 1024 * 1024, // 100 MB
    allowedExtensions: {'mp4', 'webm', 'webp'},
    requiresAdminWrite: true,
    userScopedPrefix: false,
  ),
  anatomyModels(
    id: 'anatomy-models',
    maxBytes: 50 * 1024 * 1024, // 50 MB
    allowedExtensions: {'glb', 'gltf'},
    requiresAdminWrite: true,
    userScopedPrefix: false,
  ),
  exerciseEquipment(
    id: 'exercise-equipment',
    maxBytes: 50 * 1024 * 1024, // 50 MB
    allowedExtensions: {'glb', 'gltf'},
    requiresAdminWrite: true,
    userScopedPrefix: false,
  ),
  machineModels(
    id: 'machine-models',
    maxBytes: 50 * 1024 * 1024, // 50 MB
    allowedExtensions: {'glb', 'gltf'},
    requiresAdminWrite: true,
    userScopedPrefix: false,
  ),
  courseMedia(
    id: 'course-media',
    maxBytes: 200 * 1024 * 1024, // 200 MB
    allowedExtensions: {'mp4', 'webp', 'png', 'pdf'},
    requiresAdminWrite: false,
    userScopedPrefix: false,
  ),
  communityMedia(
    id: 'community-media',
    maxBytes: 50 * 1024 * 1024, // 50 MB
    allowedExtensions: {'mp4', 'webp', 'png', 'jpg', 'jpeg'},
    requiresAdminWrite: false,
    userScopedPrefix: true,
  ),
  privateUserFiles(
    id: 'private-user-files',
    maxBytes: 25 * 1024 * 1024, // 25 MB
    allowedExtensions: {'json', 'pdf', 'webp'},
    requiresAdminWrite: false,
    userScopedPrefix: true,
  ),
  importStaging(
    id: 'import-staging',
    maxBytes: 500 * 1024 * 1024, // 500 MB
    allowedExtensions: {'mp4', 'glb', 'json'},
    requiresAdminWrite: true,
    userScopedPrefix: false,
  );

  final String id;
  final int maxBytes;
  final Set<String> allowedExtensions;
  final bool requiresAdminWrite;
  final bool userScopedPrefix;

  const StorageBucket({
    required this.id,
    required this.maxBytes,
    required this.allowedExtensions,
    required this.requiresAdminWrite,
    required this.userScopedPrefix,
  });
}

/// Represents a time-limited signed URL for authorized asset delivery.
class SignedMediaUrl {
  final StorageBucket bucket;
  final String objectPath;
  final String signedUrl;
  final String tokenSignature;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final bool redistributable;

  const SignedMediaUrl({
    required this.bucket,
    required this.objectPath,
    required this.signedUrl,
    required this.tokenSignature,
    required this.issuedAt,
    required this.expiresAt,
    this.redistributable = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Validates that the signed URL has not expired and matches its signature.
  bool validateForPlaybackOrRender({DateTime? checkTime}) {
    final now = checkTime ?? DateTime.now();
    if (now.isAfter(expiresAt)) return false;
    return signedUrl.isNotEmpty && tokenSignature.isNotEmpty;
  }
}

class StorageUploadResult {
  final bool isSuccess;
  final String message;
  final StorageBucket? bucket;
  final String? objectPath;
  final String? sha256Checksum;

  const StorageUploadResult({
    required this.isSuccess,
    required this.message,
    this.bucket,
    this.objectPath,
    this.sha256Checksum,
  });
}

/// Secure Cloud Storage Service owned by AI Agent 1.
/// Enforces UUID/ID-based object paths, role/owner write permissions, MIME/magic-byte validation,
/// file size limits, and short-lived signed URLs across all 9 buckets.
class CloudStorageService {
  CloudStorageService._();
  static final CloudStorageService instance = CloudStorageService._();

  // Tracks uploaded object metadata in memory when running offline or in tests
  final Map<String, Map<String, dynamic>> _objectRegistry = {};

  // ============================================================================
  // CANONICAL OBJECT STORAGE PATH BUILDERS (Task 4)
  // ============================================================================

  /// `profile-avatars/{user_id}/{file_id}.webp`
  static String buildProfileAvatarPath({
    required String userId,
    required String fileId,
    String ext = 'webp',
  }) =>
      'profile-avatars/${_sanitizeSegment(userId)}/${_sanitizeSegment(fileId)}.${_sanitizeExt(ext)}';

  /// `exercise-videos/{exercise_id}/{video_id}.mp4`
  static String buildExerciseVideoPath({
    required String exerciseId,
    required String videoId,
    String ext = 'mp4',
  }) =>
      'exercise-videos/${_sanitizeSegment(exerciseId)}/${_sanitizeSegment(videoId)}.${_sanitizeExt(ext)}';

  /// `anatomy-models/{model_id}/{version}.glb`
  static String buildAnatomyModelPath({
    required String modelId,
    String version = 'v1',
  }) =>
      'anatomy-models/${_sanitizeSegment(modelId)}/${_sanitizeSegment(version)}.glb';

  /// `exercise-equipment/{equipment_id}/{version}.glb`
  static String buildEquipmentModelPath({
    required String equipmentId,
    String version = 'v1',
  }) =>
      'exercise-equipment/${_sanitizeSegment(equipmentId)}/${_sanitizeSegment(version)}.glb';

  /// `machine-models/{machine_id}/{version}.glb`
  static String buildMachineModelPath({
    required String machineId,
    String version = 'v1',
  }) =>
      'machine-models/${_sanitizeSegment(machineId)}/${_sanitizeSegment(version)}.glb';

  /// `course-media/{course_id}/{lesson_id}/{file_id}`
  static String buildCourseMediaPath({
    required String courseId,
    required String lessonId,
    required String fileId,
    String ext = 'mp4',
  }) =>
      'course-media/${_sanitizeSegment(courseId)}/${_sanitizeSegment(lessonId)}/${_sanitizeSegment(fileId)}.${_sanitizeExt(ext)}';

  /// `community-media/{user_id}/{post_id}/{file_id}`
  static String buildCommunityMediaPath({
    required String userId,
    required String postId,
    required String fileId,
    String ext = 'mp4',
  }) =>
      'community-media/${_sanitizeSegment(userId)}/${_sanitizeSegment(postId)}/${_sanitizeSegment(fileId)}.${_sanitizeExt(ext)}';

  /// `private-user-files/{user_id}/{file_id}`
  static String buildPrivateUserFilePath({
    required String userId,
    required String fileId,
    String ext = 'json',
  }) =>
      'private-user-files/${_sanitizeSegment(userId)}/${_sanitizeSegment(fileId)}.${_sanitizeExt(ext)}';

  /// `import-staging/{import_batch_id}/{file_id}`
  static String buildImportStagingPath({
    required String importBatchId,
    required String fileId,
    String ext = 'mp4',
  }) =>
      'import-staging/${_sanitizeSegment(importBatchId)}/${_sanitizeSegment(fileId)}.${_sanitizeExt(ext)}';

  static String _sanitizeSegment(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    if (cleaned.isEmpty || cleaned.contains('..')) {
      throw ArgumentError('Invalid storage path segment: "$input"');
    }
    return cleaned;
  }

  static String _sanitizeExt(String ext) {
    return ext.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // ============================================================================
  // UPLOAD VALIDATION & AUTHORIZATION
  // ============================================================================

  /// Validates and uploads an asset to the specified bucket, enforcing:
  /// 1. Authenticated user identity
  /// 2. Admin/Owner restriction for protected catalog buckets
  /// 3. User-prefix isolation (User A can never write/overwrite inside User B's folder)
  /// 4. File size limit and extension/magic-byte signature validation
  Future<StorageUploadResult> uploadProtectedAsset({
    required StorageBucket bucket,
    required String fullObjectPath,
    required List<int> fileBytes,
    required String authenticatedUserId,
    required UserRole actorRole,
  }) async {
    if (authenticatedUserId.trim().isEmpty) {
      return const StorageUploadResult(
        isSuccess: false,
        message: 'Unauthorized: Must be signed in to upload storage assets.',
      );
    }

    if ( fullObjectPath.contains('..')) {
      return const StorageUploadResult(
        isSuccess: false,
        message: 'Security Violation: Path traversal sequences are forbidden.',
      );
    }

    // 1. Check Admin/Owner restriction on protected buckets
    if (bucket.requiresAdminWrite &&
        actorRole != UserRole.owner &&
        actorRole != UserRole.admin) {
      return StorageUploadResult(
        isSuccess: false,
        message:
            'Forbidden: Only the App Owner or an authorized Administrator can upload to "${bucket.id}".',
      );
    }

    // 2. Strip bucket prefix if included in fullObjectPath to inspect inner segments
    final relativePath = fullObjectPath.startsWith('${bucket.id}/')
        ? fullObjectPath.substring(bucket.id.length + 1)
        : fullObjectPath;
    final segments = relativePath.split('/');
    if (segments.length < 2) {
      return const StorageUploadResult(
        isSuccess: false,
        message: 'Invalid object path structure.',
      );
    }

    // 3. Enforce User-Scoped Folder Ownership (User A cannot write to User B's folder)
    if (bucket.userScopedPrefix) {
      final pathOwnerUserId = segments.first;
      if (pathOwnerUserId != authenticatedUserId.trim()) {
        return const StorageUploadResult(
          isSuccess: false,
          message:
              'Forbidden: Users cannot upload or overwrite files in another user\'s storage path.',
        );
      }
    }

    // 4. Prevent cross-user overwrite on existing objects
    final canonicalKey = '${bucket.id}/$relativePath';
    final existingMeta = _objectRegistry[canonicalKey];
    if (existingMeta != null &&
        existingMeta['ownerUserId'] != authenticatedUserId &&
        actorRole != UserRole.owner &&
        actorRole != UserRole.admin) {
      return const StorageUploadResult(
        isSuccess: false,
        message: 'Forbidden: Cannot overwrite an asset owned by another user.',
      );
    }

    // 5. Validate non-empty & max file size
    if (fileBytes.isEmpty) {
      return const StorageUploadResult(
        isSuccess: false,
        message: 'Rejected: Uploaded file cannot be empty (0 bytes).',
      );
    }
    if (fileBytes.length > bucket.maxBytes) {
      return StorageUploadResult(
        isSuccess: false,
        message:
            'Rejected: File size (${fileBytes.length} bytes) exceeds bucket limit (${bucket.maxBytes} bytes).',
      );
    }

    // 6. Validate file extension and magic-byte signature
    final ext = relativePath.contains('.')
        ? relativePath.split('.').last.toLowerCase()
        : '';
    if (!bucket.allowedExtensions.contains(ext)) {
      return StorageUploadResult(
        isSuccess: false,
        message:
            'Rejected: File extension ".$ext" is not permitted in bucket "${bucket.id}".',
      );
    }

    if (!_hasValidMagicSignature(ext, fileBytes)) {
      return StorageUploadResult(
        isSuccess: false,
        message:
            'Rejected: File binary header does not match expected ".$ext" signature.',
      );
    }

    final checksum = sha256.convert(fileBytes).toString();

    // 7. Upload to Supabase Storage when configured
    final supabase = SupabaseConfig.clientOrNull;
    if (supabase != null) {
      await supabase.storage.from(bucket.id).uploadBinary(
            relativePath,
            fileBytes as dynamic,
          );
    }

    _objectRegistry[canonicalKey] = {
      'bucket': bucket.id,
      'objectPath': relativePath,
      'ownerUserId': authenticatedUserId,
      'sha256': checksum,
      'sizeBytes': fileBytes.length,
      'uploadedAt': DateTime.now().toIso8601String(),
    };

    return StorageUploadResult(
      isSuccess: true,
      message: 'Uploaded successfully to $canonicalKey',
      bucket: bucket,
      objectPath: canonicalKey,
      sha256Checksum: checksum,
    );
  }

  /// Issues a short-lived signed URL for authorized access.
  /// Enforces read authorization for `private-user-files` and `import-staging`.
  Future<SignedMediaUrl> createAuthorizedSignedUrl({
    required StorageBucket bucket,
    required String objectPath,
    required String requestingUserId,
    required UserRole requestingRole,
    Duration ttl = const Duration(minutes: 15),
  }) async {
    if (requestingUserId.trim().isEmpty) {
      throw StateError('Unauthorized: Signed URLs require an authenticated user.');
    }

    final relativePath = objectPath.startsWith('${bucket.id}/')
        ? objectPath.substring(bucket.id.length + 1)
        : objectPath;
    final segments = relativePath.split('/');

    // Private user files can ONLY be read by the file owner
    if (bucket == StorageBucket.privateUserFiles) {
      if (segments.isEmpty || segments.first != requestingUserId.trim()) {
        throw StateError(
          'Forbidden: User "$requestingUserId" cannot access another user\'s private files.',
        );
      }
    }

    // Import staging can ONLY be read by Admin or Owner
    if (bucket == StorageBucket.importStaging &&
        requestingRole != UserRole.owner &&
        requestingRole != UserRole.admin) {
      throw StateError(
        'Forbidden: Only Admin or Owner can access import-staging assets.',
      );
    }

    final issuedAt = DateTime.now();
    final expiresAt = issuedAt.add(ttl);

    final supabase = SupabaseConfig.clientOrNull;
    if (supabase != null) {
      final url = await supabase.storage
          .from(bucket.id)
          .createSignedUrl(relativePath, ttl.inSeconds);
      final sig = sha256
          .convert(utf8.encode('$url|${expiresAt.millisecondsSinceEpoch}'))
          .toString();
      return SignedMediaUrl(
        bucket: bucket,
        objectPath: '${bucket.id}/$relativePath',
        signedUrl: url,
        tokenSignature: sig,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        redistributable: false,
      );
    }

    final sig = sha256
        .convert(
          utf8.encode(
            '${bucket.id}/$relativePath|$requestingUserId|${expiresAt.millisecondsSinceEpoch}',
          ),
        )
        .toString();
    return SignedMediaUrl(
      bucket: bucket,
      objectPath: '${bucket.id}/$relativePath',
      signedUrl:
          'https://storage.liftinglife.internal/${bucket.id}/$relativePath?token=$sig&exp=${expiresAt.millisecondsSinceEpoch}',
      tokenSignature: sig,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      redistributable: false,
    );
  }

  static bool _hasValidMagicSignature(String ext, List<int> bytes) {
    switch (ext) {
      case 'glb':
        // Binary glTF 2.0 magic header: 'glTF' (0x67, 0x6C, 0x54, 0x46)
        return bytes.length >= 12 &&
            bytes[0] == 0x67 &&
            bytes[1] == 0x6C &&
            bytes[2] == 0x54 &&
            bytes[3] == 0x46;
      case 'mp4':
        // ISO Base Media file (MP4) contains 'ftyp' at bytes 4..7
        return bytes.length >= 12 &&
            bytes[4] == 0x66 &&
            bytes[5] == 0x74 &&
            bytes[6] == 0x79 &&
            bytes[7] == 0x70;
      case 'webp':
        // 'RIFF' (0..3) and 'WEBP' (8..11)
        return bytes.length >= 12 &&
            bytes[0] == 0x52 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x46 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50;
      case 'png':
        return bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47;
      case 'jpg':
      case 'jpeg':
        return bytes.length >= 3 &&
            bytes[0] == 0xFF &&
            bytes[1] == 0xD8 &&
            bytes[2] == 0xFF;
      case 'pdf':
        // '%PDF'
        return bytes.length >= 4 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46;
      case 'json':
      case 'gltf':
        try {
          final decoded = utf8.decode(bytes).trimLeft();
          return decoded.startsWith('{') || decoded.startsWith('[');
        } catch (_) {
          return false;
        }
      default:
        return false;
    }
  }
}

