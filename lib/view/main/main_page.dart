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
  late Query _currentQuery;

  @override
  void initState() {
    super.initState();
    _currentQuery = FirebaseFirestore.instance.collection('files');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(Constant.APP_NAME),
        actions: [
          IconButton(
            onPressed: () async {
              var result = await showDialog(
                context: context,
                builder: (context) => const MusicSearchDialog(),
              );

              if (result != null && result is Query) {
                setState(() {
                  _currentQuery = result;
                });
              }
            },
            icon: const Icon(Icons.search),
          ),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _currentQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('음악 정보가 없습니다.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              Music music = Music.fromStoreData(docs[index]);

              return DownloadListTile(
                music: music,
                database: widget.database, // DB 전달
              );
            },
          );
        },
      ),
    );
  }
}