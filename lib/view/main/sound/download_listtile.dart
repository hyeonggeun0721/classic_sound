import 'dart:io';
import 'package:classic_sound/data/local_database.dart';
import 'package:classic_sound/data/music.dart';
import 'package:classic_sound/view/main/sound/sound_detail_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DownloadListTile extends StatefulWidget {
  final Music music;
  final Database database;

  const DownloadListTile({
    super.key,
    required this.music,
    required this.database,
  });

  @override
  State<DownloadListTile> createState() => _DownloadListTileState();
}

class _DownloadListTileState extends State<DownloadListTile> {
  double progress = 0.0;
  bool isDownloading = false;
  bool isDownloaded = false; // [추가] 이미 다운로드 되었는지 확인하는 변수
  IconData leadingIcon = Icons.music_note;

  @override
  void initState() {
    super.initState();
    // [추가] 위젯이 생성될 때 파일이 있는지 먼저 확인
    _checkFileStatus();
  }

  // 파일 경로 가져오기
  Future<String> _getFilePath() async {
    var dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${widget.music.name}';
  }

  // 파일 존재 여부 확인 함수
  Future<void> _checkFileStatus() async {
    try {
      var path = await _getFilePath();
      var file = File(path);
      bool exists = await file.exists();

      if (mounted) {
        setState(() {
          isDownloaded = exists;
        });
      }
    } catch (e) {
      print("파일 체크 오류: $e");
    }
  }

  // 상세 페이지 이동 로직
  void _goToDetailPage() {
    if (isDownloaded) {
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return SoundDetailPage(
            music: widget.music,
            database: widget.database,
          );
        }));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일을 먼저 다운로드 해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: _goToDetailPage, // 리스트를 누르면 상세 페이지 이동 시도
        leading: Icon(leadingIcon),
        title: Text(
          widget.music.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${widget.music.composer} / ${widget.music.tag}'),

        // [수정] 3단 상태 변화 (다운로드중 vs 완료됨 vs 다운로드전)
        trailing: _buildTrailingIcon(),
      ),
    );
  }

  Widget _buildTrailingIcon() {
    // 1. 다운로드 중일 때: 로딩바 표시
    if (isDownloading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 3.0,
        ),
      );
    }

    // 2. 이미 다운로드 완료된 상태일 때: 체크 표시 (클릭 시 아무것도 안 하거나, 삭제 안내)
    if (isDownloaded) {
      return IconButton(
        icon: const Icon(Icons.check_circle, color: Colors.green), // 체크 아이콘
        onPressed: () {
          // 이미 다운로드 되었으므로 다시 다운로드하지 않음
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 다운로드된 파일입니다. 리스트를 눌러 재생하세요.'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      );
    }

    // 3. 다운로드가 안 된 상태일 때: 다운로드 버튼
    return IconButton(
      icon: const Icon(Icons.download_for_offline_outlined),
      onPressed: () async {
        var path = await _getFilePath();
        _startDownload(widget.music.downloadUrl, path);
      },
    );
  }

  Future<void> _startDownload(String url, String path) async {
    setState(() {
      isDownloading = true;
    });

    try {
      await Dio().download(
        url,
        path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              progress = received / total;
            });
          }
        },
      );

      // DB 저장
      try {
        await MusicDatabase(widget.database).insertMusic(widget.music);
      } catch (e) {
        // 중복 저장 등 에러 무시
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다운로드 완료!')),
        );

        // [중요] 다운로드가 끝나면 '완료됨' 상태로 변경 -> 체크 아이콘으로 바뀜
        setState(() {
          isDownloaded = true;
        });
      }
    } catch (e) {
      print("다운로드 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
          progress = 0.0;
        });
      }
    }
  }
}