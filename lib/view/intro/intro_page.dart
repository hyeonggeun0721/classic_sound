import 'dart:async';
import 'package:classic_sound/data/constant.dart';
import 'package:classic_sound/view/main/main_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_page.dart';
import 'package:sqflite/sqflite.dart';
import '../user/user_page.dart';

class IntroPage extends StatefulWidget {
  final Database database;
  const IntroPage({super.key, required this.database});

  @override
  State<StatefulWidget> createState() {
    return _IntroPageState();
  }
}

class _IntroPageState extends State<IntroPage> {
  // 인터넷 연결 상태를 확인하기 위한 라이브러리 객체
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  bool _isDialogOpen = false; // 중복 다이얼로그 방지
  bool _isConnected = false;  // 인터넷 연결 여부 저장

  // [자동 로그인 체크]
  // SharedPreferences에 저장된 아이디/비번이 있으면 Firebase 로그인을 시도
  Future<bool> _loginCheck() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    String? id = preferences.getString("id");
    String? pw = preferences.getString("pw");

    // 저장된 정보가 있다면 로그인 시도
    if (id != null && pw != null){
      final FirebaseAuth auth = FirebaseAuth.instance;
      try {
        await auth.signInWithEmailAndPassword(email: id, password: pw);
        return true; // 로그인 성공
      } on FirebaseAuthException catch (e) {
        return false; // 로그인 실패
      }
    } else {
      return false; // 저장된 정보 없음
    }
  }

  @override
  void initState() {
    super.initState();
    // 앱이 시작될 때 인터넷 연결 상태를 감지
    _initConnectivity();
  }

  // 초기 연결 상태 확인 및 리스너 등록
  Future<void> _initConnectivity() async {
    List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    // 실시간으로 연결 상태가 변하는지 감지 (와이파이 <-> 데이터)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  // 연결 상태에 따라 페이지 이동 로직 처리
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    // 모바일 데이터나 와이파이에 연결되어 있는지 확인
    for (var element in result) {
      if (element == ConnectivityResult.mobile || element == ConnectivityResult.wifi) {
        setState(() {
          _isConnected = true;
        });
      }
    }

    if (_isConnected) {
      // 연결되면 오프라인 안내 다이얼로그 닫기
      if (_isDialogOpen) {
        Navigator.of(context).pop();
        _isDialogOpen = false;
      }

      // 로그인 정보 확인 후 페이지 이동 (2초 딜레이로 로고 보여줌)
      _loginCheck().then((value){
        if(value == true) {
          // 자동 로그인 성공 -> 메인 페이지로 이동
          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MainPage(database: widget.database,)),
              );
            }
          });
        } else {
          // 자동 로그인 실패/정보 없음 -> 로그인 페이지로 이동
          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AuthPage(database: widget.database,)),
              );
            }
          });
        }
      });
    } else {
      // 인터넷 연결 안 됨 -> 오프라인 모드 안내
      _showOfflineDialog();
    }
  }

  // 인터넷 미연결 시 오프라인 모드(UserPage)로 유도하는 다이얼로그
  void _showOfflineDialog() {
    if (!_isDialogOpen && mounted) {
      _isDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false, // 바깥 터치로 닫기 방지
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(Constant.APP_NAME,),
            content: const Text('지금은 인터넷에 연결되지 않아 앱을 사용할 수 없습니다. 나중에 다시 실행해주세요.',),
            actions: [
              TextButton(
                onPressed: () {
                  // 오프라인 페이지(다운로드함)로 이동
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => UserPage(database: widget.database)
                    ), );
                  _isDialogOpen = false;
                },
                child: const Text('오프라인으로 사용'),
              ),
            ],
          );
        },
      ).then((_) => _isDialogOpen = false);
    }
  }

  @override
  void dispose() {
    // 메모리 누수 방지를 위해 리스너 해제
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // 인터넷 연결되면 로고 표시, 아니면 로딩 중 표시
        child: _isConnected
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Constant.APP_NAME,
                style: TextStyle(fontSize: 50),
              ),
              SizedBox(height: 20),
              Icon(Icons.audiotrack, size: 100)
            ],
          ),
        )
            : const CircularProgressIndicator(),
      ),
    );
  }
}