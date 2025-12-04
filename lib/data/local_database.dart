import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'music.dart';

class MusicDatabase {
  final Database database;

  MusicDatabase(this.database);

  static Future<Database> initDatabase() async {
    return openDatabase(
      join(await getDatabasesPath(), 'music_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE music('
              'id INTEGER PRIMARY KEY,'
              'name TEXT,'
              'composer TEXT,'
              'tag TEXT,'
              'category TEXT,'
              'size INTEGER,'
              'type TEXT,'
              'downloadUrl TEXT,'
              'imageDownloadUrl TEXT'
              ')',
        );
      },
      version: 1,
    );
  }

  Future<void> insertMusic(Music music) async {
    // 이미 열려있는 this.database를 사용합니다.
    try {
      await database.insert(
        'music',
        music.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("---- [DB 저장 성공] : ${music.name} ----");
    } catch (e) {
      print("---- [DB 저장 실패] : $e ----");
    }
  }

  Future<List<Map<String, dynamic>>> getMusic() async {
    // [수정 핵심] 새로 openDatabase 하지 않고, 기존 연결(this.database)을 사용해야 합니다!
    // 이렇게 해야 테이블이 존재하는지 확실하게 알 수 있습니다.
    try {
      final List<Map<String, dynamic>> maps = await database.query('music');
      return maps;
    } catch (e) {
      print("데이터 조회 실패 (테이블이 없을 수 있음): $e");
      return [];
    }
  }

  // [수정 핵심] 파일을 삭제하지 않고, 테이블의 내용만 비웁니다.
  // 파일을 삭제하면 앱을 재시작하기 전까지 DB 연결이 끊기는 오류가 발생합니다.
  Future<void> deleteMusicDatabase() async {
    try {
      // 'DELETE FROM music'과 같은 효과입니다.
      await database.delete('music');
      print("---- [DB 초기화 완료] 테이블을 비웠습니다. ----");
    } catch (e) {
      print("---- [DB 초기화 실패] : $e ----");
    }
  }
}