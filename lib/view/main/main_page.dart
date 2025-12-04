import 'package:classic_sound/data/constant.dart';
import 'package:classic_sound/data/music.dart';
import 'package:classic_sound/view/main/sound/download_listtile.dart';
import 'package:classic_sound/view/main/sound/sound_search_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'drawer_widget.dart';

class MainPage extends StatefulWidget {
  final Database database;
  const MainPage({super.key, required this.database});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late Query _currentQuery; // 현재 보여줄 데이터 쿼리 (전체보기 or 검색결과)

  @override
  void initState() {
    super.initState();
    // 초기에는 모든 파일 목록을 가져오도록 설정
    _currentQuery = FirebaseFirestore.instance.collection('files');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(Constant.APP_NAME),
        actions: [
          // [검색 버튼]
          IconButton(
            onPressed: () async {
              // 검색 다이얼로그를 띄우고 결과를 기다림 (await)
              var result = await showDialog(
                context: context,
                builder: (context) => const MusicSearchDialog(),
              );

              // 검색 결과(Query 객체)가 넘어왔다면 리스트 갱신
              if (result != null && result is Query) {
                setState(() {
                  _currentQuery = result;
                });
              }
            },
            icon: const Icon(Icons.search),
          ),
          // [새로고침 버튼] - 전체 목록으로 초기화
          IconButton(
            onPressed: () {
              setState(() {
                _currentQuery = FirebaseFirestore.instance.collection('files');
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: Drawer(child: DrawerWidget(database: widget.database)),
      // StreamBuilder를 사용하여 Firestore 데이터가 변경되면 실시간으로 화면 갱신
      body: StreamBuilder<QuerySnapshot>(
        stream: _currentQuery.snapshots(),
        builder: (context, snapshot) {
          // 데이터 로딩 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 에러 발생 시
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }
          // 데이터가 없을 때
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('음악 정보가 없습니다.'));
          }

          final docs = snapshot.data!.docs;

          // 리스트뷰로 음악 목록 표시
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              // Firestore 문서를 Music 객체로 변환
              Music music = Music.fromStoreData(docs[index]);

              // 각 항목은 별도 위젯(DownloadListTile)으로 분리
              return DownloadListTile(
                music: music,
                database: widget.database,
              );
            },
          );
        },
      ),
    );
  }
}