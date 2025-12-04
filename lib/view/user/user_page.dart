import 'package:classic_sound/data/local_database.dart';
import 'package:classic_sound/view/main/sound/download_listtile.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/music.dart';

class UserPage extends StatefulWidget {
  final Database database;

  const UserPage({super.key, required this.database});

  @override
  State<StatefulWidget> createState() {
    return _UserPage();
  }
}

class _UserPage extends State<UserPage> {
  // [삭제] Future 변수와 initState 삭제
  // 이유: 변수에 담아두면 새 데이터를 못 가져옴

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내가 내려받은 음악'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // [수정] 변수 대신 여기서 함수를 바로 실행!
        // 화면이 그려질 때마다 DB에서 최신 목록을 새로 가져옵니다.
        future: MusicDatabase(widget.database).getMusic(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) { // 데이터가 비어있지 않은지도 체크 추천
              final data = snapshot.data!; // ! 붙여서 null 아님을 명시

              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final musicData = data[index]; // 변수명 겹침 방지

                  return DownloadListTile(
                    music: Music(
                      musicData['name'],
                      musicData['composer'],
                      musicData['tag'],
                      musicData['category'],
                      musicData['size'],
                      musicData['type'],
                      musicData['downloadUrl'],
                      musicData['imageDownloadUrl'],
                    ),
                    database: widget.database,
                  );
                },
              );
            } else {
              // 데이터가 없거나 비어있을 때
              return const Center(
                child: Text('다운로드된 음악이 없습니다.'),
              );
            }
          } else {
            // 로딩 중
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}