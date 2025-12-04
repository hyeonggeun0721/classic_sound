import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MusicSearchDialog extends StatefulWidget {
  const MusicSearchDialog({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MusicSearchDialog();
  }
}

class _MusicSearchDialog extends State<MusicSearchDialog> {
  String dropdownValue = 'name'; // 기본 검색 조건: 이름
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Music 클래스 검색'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 검색할 필드 선택 (이름, 작곡가 등)
          DropdownButton<String>(
            value: dropdownValue,
            onChanged: (newValue) {
              setState(() {
                dropdownValue = newValue!;
              });
            },
            items: <String>['name', 'composer', 'tag', 'category']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          // 검색어 입력 필드
          TextField(
            controller: searchController,
            decoration: InputDecoration(hintText: '검색어를 입력하세요.'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // 취소 시 그냥 닫기
          },
          child: Text('취소'),
        ),
        TextButton(
          onPressed: () {
            // 입력된 검색어로 Firestore 쿼리 생성
            var result = searchMusicList(searchController.value.text);
            // 결과를 메인 페이지로 전달하며 닫기
            Navigator.of(context).pop(result);
          },
          child: Text('검색'),
        ),
      ],
    );
  }

  // Firestore 검색 쿼리 생성 함수
  Query searchMusicList(String searchKeyword) {
    Query query = FirebaseFirestore.instance
        .collection('files')
        .where(dropdownValue, isGreaterThanOrEqualTo: searchKeyword)
        .where(dropdownValue, isLessThanOrEqualTo: '$searchKeyword\uf8ff');
    return query;
  }
}