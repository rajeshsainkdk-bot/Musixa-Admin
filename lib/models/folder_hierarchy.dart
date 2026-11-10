import 'package:flutter/foundation.dart';

class DetectedFolderHierarchy {
  final String category;
  final String? subCategory;

  const DetectedFolderHierarchy({required this.category, this.subCategory});

  static DetectedFolderHierarchy fromPath(String filePath, {String? rootFolderPath}) {
    final cleanPath = filePath.replaceAll(r'\', '/');

    // 1. If rootFolderPath was picked, use relative folder structure
    if (rootFolderPath != null && rootFolderPath.trim().isNotEmpty) {
      final cleanRoot = rootFolderPath.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
      if (cleanPath.startsWith(cleanRoot)) {
        final relative = cleanPath.substring(cleanRoot.length).replaceAll(RegExp(r'^/+'), '');
        final relParts = relative.split('/').where((p) => p.trim().isNotEmpty).toList();
        final rootParts = cleanRoot.split('/').where((p) => p.trim().isNotEmpty).toList();
        final rootFolderName = rootParts.isNotEmpty ? rootParts.last : 'Rajasthani';

        if (relParts.length <= 1) {
          // File directly in root folder: Category = rootFolderName, SubCategory = null
          return DetectedFolderHierarchy(category: rootFolderName, subCategory: null);
        } else {
          // File in subfolder inside root folder: Category = rootFolderName, SubCategory = immediate subfolder
          final subFolder = relParts.first;
          return DetectedFolderHierarchy(category: rootFolderName, subCategory: subFolder);
        }
      }
    }

    // 2. Generic path inspection
    final parts = cleanPath.split('/').where((p) => p.trim().isNotEmpty).toList();
    if (parts.length < 2) {
      return const DetectedFolderHierarchy(category: 'Rajasthani');
    }
    const systemFolders = {
      'storage', 'emulated', '0', '1', 'sdcard', 'android', 'media', 'data',
      'download', 'downloads', 'music', 'audio', 'documents', 'dcim', 'desktop',
      'c:', 'd:', 'e:', 'users', 'user', 'home', 'appdata', 'temp', 'tmp'
    };
    final parentDir = parts[parts.length - 2];
    final grandParentDir = parts.length >= 3 ? parts[parts.length - 3] : null;

    if (grandParentDir != null && !systemFolders.contains(grandParentDir.toLowerCase())) {
      return DetectedFolderHierarchy(
        category: grandParentDir,
        subCategory: parentDir,
      );
    } else {
      final cat = systemFolders.contains(parentDir.toLowerCase()) ? 'Rajasthani' : parentDir;
      return DetectedFolderHierarchy(
        category: cat,
        subCategory: null,
      );
    }
  }

  /// Resolves Android SAF (content://) tree URIs to standard device storage paths
  static String resolveSafPath(String pathOrUri) {
    if (!pathOrUri.startsWith('content://')) return pathOrUri;
    try {
      final decoded = Uri.decodeFull(pathOrUri);
      if (decoded.contains('primary:')) {
        final sub = decoded.split('primary:').last;
        return '/storage/emulated/0/$sub';
      } else if (decoded.contains('raw:')) {
        return decoded.split('raw:').last;
      } else {
        final match = RegExp(r'tree\/([A-Za-z0-9\-]+):(.*)').firstMatch(decoded);
        if (match != null) {
          return '/storage/${match.group(1)}/${match.group(2)}';
        }
      }
    } catch (e) {
      debugPrint('SAF resolve error: $e');
    }
    return pathOrUri;
  }
}

