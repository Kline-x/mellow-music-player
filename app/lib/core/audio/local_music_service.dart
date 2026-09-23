import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'track_model.dart';
import '../storage/storage_service.dart';

/// 本地音频文件扫描与曲库管理引擎
class LocalMusicService {
  static final LocalMusicService instance = LocalMusicService._internal();

  LocalMusicService._internal() {
    loadFromStorage();
  }

  static const List<String> supportedExtensions = [
    '.flac',
    '.mp3',
    '.wav',
    '.ogg',
    '.m4a',
    '.aac',
  ];

  final List<Track> _localTracks = [];
  final List<String> _scannedDirectories = [];

  List<Track> get localTracks => List.unmodifiable(_localTracks);
  List<String> get scannedDirectories => List.unmodifiable(_scannedDirectories);

  /// 从持久化中读取本地曲库
  void loadFromStorage() {
    final savedTracks = StorageService.instance.getLocalTracks();
    if (savedTracks != null && savedTracks.isNotEmpty) {
      _localTracks.clear();
      _localTracks.addAll(savedTracks);
    }

    final savedDirs = StorageService.instance.getLocalDirectories();
    if (savedDirs != null && savedDirs.isNotEmpty) {
      _scannedDirectories.clear();
      _scannedDirectories.addAll(savedDirs);
    }
  }

  /// 扫描指定本地目录
  Future<int> scanDirectory(String dirPath, {bool recursive = true}) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      debugPrint('[LocalMusicService] 目录不存在: $dirPath');
      return 0;
    }

    if (!_scannedDirectories.contains(dirPath)) {
      _scannedDirectories.add(dirPath);
      await StorageService.instance.saveLocalDirectories(_scannedDirectories);
    }

    int addedCount = 0;
    try {
      final fileList = dir.listSync(recursive: recursive, followLinks: false);
      for (final entity in fileList) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            // 避免重复添加同路径曲目
            if (!_localTracks.any((t) => t.localPath == entity.path)) {
              final track = parseAudioFile(entity);
              _localTracks.add(track);
              addedCount++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalMusicService] 目录扫描异常: $e');
    }

    if (addedCount > 0) {
      await StorageService.instance.saveLocalTracks(_localTracks);
    }
    return addedCount;
  }

  /// 智能解析音频文件并生成 Track 实体
  Track parseAudioFile(File file) {
    final filenameWithoutExt = p.basenameWithoutExtension(file.path);
    final ext = p.extension(file.path).replaceAll('.', '').toUpperCase();

    String artist = '本地音乐';
    String title = filenameWithoutExt;

    // 智能切分 "歌手 - 歌曲名"
    if (filenameWithoutExt.contains(' - ')) {
      final parts = filenameWithoutExt.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    } else if (filenameWithoutExt.contains('_')) {
      final parts = filenameWithoutExt.split('_');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join('_').trim();
      }
    }

    final id = 'local_${file.path.hashCode.abs()}';

    return Track(
      id: id,
      title: title.isNotEmpty ? title : '未知音频',
      artist: artist.isNotEmpty ? artist : '本地音乐人',
      album: '本地 $ext 离线曲库',
      duration: const Duration(minutes: 3, seconds: 40),
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
      localPath: file.path,
      audioUrl: null,
      lyrics: [
        LyricLine(time: Duration.zero, text: '♪ $title - $artist ♪'),
        const LyricLine(time: Duration(seconds: 4), text: '本地音频文件，物理声卡直接解码输出'),
        const LyricLine(time: Duration(seconds: 12), text: 'Mellow Music · 润音 无损音频引擎'),
      ],
    );
  }

  /// 手动新增本地曲目
  void addLocalTrack(Track track) {
    if (!_localTracks.any((t) => t.id == track.id || t.localPath == track.localPath)) {
      _localTracks.insert(0, track);
      StorageService.instance.saveLocalTracks(_localTracks);
    }
  }

  /// 移除单首本地曲目
  void removeLocalTrack(String trackId) {
    _localTracks.removeWhere((t) => t.id == trackId);
    StorageService.instance.saveLocalTracks(_localTracks);
  }

  /// 清空本地曲库
  void clearLocalTracks() {
    _localTracks.clear();
    _scannedDirectories.clear();
    StorageService.instance.saveLocalTracks(_localTracks);
    StorageService.instance.saveLocalDirectories(_scannedDirectories);
  }
}
