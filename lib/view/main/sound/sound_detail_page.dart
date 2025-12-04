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

              SizedBox(
                width: 180,  // [수정] 300에서 200으로 줄임 (적당한 크기)
                height: 180, // [수정] 높이도 동일하게
                child: ClipOval(
                  child: Image.network(
                    currentMusic.imageDownloadUrl,
                    fit: BoxFit.cover, // 원 안에 꽉 차게
                    errorBuilder: (context, obj, err) {
                      return const Icon(
                        Icons.music_note_outlined,
                        size: 100, // 에러 아이콘 크기도 조절
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// 제목 + 작곡가
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

              /// 좋아요 / 싫어요 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// 좋아요 버튼
                  IconButton(
                    onPressed: () async {
                      DocumentReference musicRef =
                      firestore.collection('musics').doc(currentMusic.name);

                      await musicRef.update({
                        'likes': FieldValue.increment(1),
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('좋아요 클릭했어요!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.thumb_up),
                    padding: const EdgeInsets.all(5),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                    ),
                  ),

                  const SizedBox(width: 20),

                  /// 싫어요 버튼
                  IconButton(
                    onPressed: () async {
                      DocumentReference musicRef =
                      firestore.collection('musics').doc(currentMusic.name);

                      await musicRef.update({
                        'likes': FieldValue.increment(-1),
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('싫어요 클릭했어요!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.thumb_down),
                    padding: const EdgeInsets.all(5),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                    ),
                  ),
                ],
              ),

              /// 플레이어 위젯
              PlayerWidget(
                player: player,
                music: currentMusic,
                database: widget.database,
                callback: (music) {
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
