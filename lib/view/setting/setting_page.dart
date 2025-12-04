import 'dart:io'; // [필수 추가] 파일 삭제를 위해 필요
import 'package:classic_sound/data/local_database.dart';
import 'package:classic_sound/view/intro/intro_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; // [필수 추가] 경로 찾기 위해 필요
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class SettingPage extends StatefulWidget {
  final Database database;
  const SettingPage({super.key, required this.database});

  @override
  State<StatefulWidget> createState() {
    return _SettingPage();
  }
}

class _SettingPage extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              final SharedPreferences preferences =
              await SharedPreferences.getInstance();
              await preferences.setString("id", "");
              await preferences.setString("pw", "");

              await FirebaseAuth.instance.signOut().then((value) async {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) {
                      return IntroPage(database: widget.database);
                    }), (route) => false);
              });
            },
            child: const Text('Log out'),
          ),
          const SizedBox(height: 20), // 버튼 사이 간격 조금 추가
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // 위험한 버튼이니 빨간색 추천
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              bool confirm = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('데이터 완전 삭제'),
                    content: const Text(
                        '다운로드된 모든 음악 파일과\n데이터베이스 기록을 삭제하시겠습니까?\n(되돌릴 수 없습니다)'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('아니오'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('예, 모두 삭제합니다'),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                try {
                  // 1. 실제 파일들(좀비 파일) 싹 지우기
                  final dir = await getApplicationDocumentsDirectory();
                  // 폴더 내의 모든 파일 리스트를 가져옴
                  final List<FileSystemEntity> entities = dir.listSync();

                  for (FileSystemEntity entity in entities) {
                    // 파일이면 삭제 (폴더는 놔둠)
                    if (entity is File) {
                      await entity.delete();
                    }
                  }
                  print("모든 로컬 파일 삭제 완료");

                  // 2. 데이터베이스(장부) 지우기
                  await MusicDatabase(widget.database).deleteMusicDatabase();
                  print("DB 데이터 삭제 완료");

                  // 3. 완료 메시지
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('모든 데이터가 깔끔하게 초기화되었습니다.')),
                    );
                  }
                } catch (e) {
                  print("삭제 중 오류 발생: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('삭제 실패: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('데이터 및 파일 전체 삭제'),
          ),
        ],
      ),
    );
  }
}