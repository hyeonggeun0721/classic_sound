import 'package:audioplayers/audioplayers.dart';
import 'package:classic_sound/data/music.dart';
import 'package:classic_sound/view/main/sound/player_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class SoundDetailPage extends StatefulWidget {
  final Music music;
  final Database database;
  const SoundDetailPage({super.key, required this.music, required this.database});

  @override
  State<StatefulWidget> createState() {
    return _SoundDetailPage();
  }
}

class _SoundDetailPage extends State<SoundDetailPage> {
  AudioPlayer player = AudioPlayer();
  late Music currentMusic;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    currentMusic = widget.music;
    initPlayer();
  }

  // 로컬에 저장된 음악 파일 경로를 찾아 플레이어에 설정
  void initPlayer() async {
    var dir = await getApplicationDocumentsDirectory();
    var path = '${dir.path}/${currentMusic.name}';
    player.setSourceDeviceFile(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 뒤로가기 버튼 영역
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 앨범 커버 이미지 (원형으로 자르기)
              SizedBox(
                width: 180,
                height: 180,
                child: ClipOval(
                  child: Image.network(
                    currentMusic.imageDownloadUrl,
                    fit: BoxFit.cover, // 이미지가 원 안에 꽉 차도록 설정
                    errorBuilder: (context, obj, err) {
                      // 이미지 로드 실패 시 대체 아이콘
                      return const Icon(
                        Icons.music_note_outlined,
                        size: 100,
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 노래 제목 및 작곡가 표시
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentMusic.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(currentMusic.composer),
                ],
              ),

              const SizedBox(height: 20),

              // [좋아요 / 싫어요 버튼] - Firestore 연동
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 좋아요 버튼
                  IconButton(
                    onPressed: () async {
                      DocumentReference musicRef =
                      firestore.collection('musics').doc(currentMusic.name);

                      // [중요] set()과 merge: true 옵션을 사용
                      // 문서가 없으면 새로 생성하고, 있으면 likes 필드만 업데이트
                      await musicRef.set({
                        'likes': FieldValue.increment(1), // 기존 값에서 1 증가
                      }, SetOptions(merge: true));

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('좋아요 클릭했어요!'),
                            duration: Duration(milliseconds: 500),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.thumb_up),
                    padding: const EdgeInsets.all(12),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      iconSize: 28,
                    ),
                  ),

                  const SizedBox(width: 30),

                  // 싫어요 버튼
                  IconButton(
                    onPressed: () async {
                      DocumentReference musicRef =
                      firestore.collection('musics').doc(currentMusic.name);

                      // 좋아요와 동일하게 동작하며 값만 감소시킴
                      await musicRef.set({
                        'likes': FieldValue.increment(-1),
                      }, SetOptions(merge: true));

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('싫어요 클릭했어요!'),
                            duration: Duration(milliseconds: 500),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.thumb_down),
                    padding: const EdgeInsets.all(12),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      iconSize: 28,
                    ),
                  ),
                ],
              ),

              // 재생 컨트롤러 위젯 (재생/일시정지/탐색 등)
              PlayerWidget(
                player: player,
                music: currentMusic,
                database: widget.database,
                callback: (music) {
                  // 다음 곡 등으로 변경되었을 때 상태 업데이트
                  setState(() {
                    currentMusic = music as Music;
                  });
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}