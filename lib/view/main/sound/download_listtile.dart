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
  double progress = 0.0;      // 다운로드 진행률
  bool isDownloading = false; // 현재 다운로드 중인지 여부
  bool isDownloaded = false;  // 파일이 로컬에 존재하는지 여부
  IconData leadingIcon = Icons.music_note;

  @override
  void initState() {
    super.initState();
    // 위젯이 생성될 때 이미 다운로드된 파일인지 확인
    _checkFileStatus();
  }

  // 앱의 내부 저장소 경로 + 파일명을 반환하는 함수
  Future<String> _getFilePath() async {
    var dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${widget.music.name}';
  }

  // 실제 파일 존재 여부를 체크하여 UI 상태를 업데이트
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

  // 리스트 아이템 클릭 시 상세 페이지 이동 로직
  void _goToDetailPage() {
    if (isDownloaded) {
      // 다운로드가 완료된 파일만 상세 페이지로 이동 가능
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return SoundDetailPage(
            music: widget.music,
            database: widget.database,
          );
        }));
      }
    } else {
      // 다운로드 안 된 경우 안내 메시지
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
        onTap: _goToDetailPage,
        leading: Icon(leadingIcon),
        title: Text(
          widget.music.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${widget.music.composer} / ${widget.music.tag}'),

        // 상태에 따라 다른 아이콘(버튼)을 보여줌
        trailing: _buildTrailingIcon(),
      ),
    );
  }

  // 상태별 아이콘 빌더 함수
  Widget _buildTrailingIcon() {
    // 1. 다운로드 중일 때: 프로그레스 바 표시
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

    // 2. 이미 다운로드 완료된 상태: 체크 아이콘 표시
    if (isDownloaded) {
      return IconButton(
        icon: const Icon(Icons.check_circle, color: Colors.green),
        onPressed: () {
          // 이미 받은 파일임을 사용자에게 알림
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 다운로드된 파일입니다. 리스트를 눌러 재생하세요.'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      );
    }

    // 3. 다운로드가 안 된 상태: 다운로드 버튼 표시
    return IconButton(
      icon: const Icon(Icons.download_for_offline_outlined),
      onPressed: () async {
        var path = await _getFilePath();
        _startDownload(widget.music.downloadUrl, path);
      },
    );
  }

  // Dio 패키지를 이용한 파일 다운로드 및 로컬 DB 저장
  Future<void> _startDownload(String url, String path) async {
    setState(() {
      isDownloading = true;
    });

    try {
      // 파일 다운로드 시작 및 진행률 업데이트
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

      // 다운로드 완료 후 음악 정보를 로컬 DB(SQFlite)에 저장
      try {
        await MusicDatabase(widget.database).insertMusic(widget.music);
      } catch (e) {
        // 이미 DB에 있는 경우 등 예외 처리
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다운로드 완료!')),
        );

        // UI 상태를 '완료됨'으로 변경 -> 체크 아이콘으로 바뀜
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
      // 성공하든 실패하든 로딩 상태 해제
      if (mounted) {
        setState(() {
          isDownloading = false;
          progress = 0.0;
        });
      }
    }
  }
}