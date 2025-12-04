import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:classic_sound/data/local_database.dart';
import 'package:classic_sound/data/music.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class PlayerWidget extends StatefulWidget {
  final AudioPlayer player;
  final Music music;
  final Database database;
  final Function(Music) callback; // 부모 위젯에게 곡 변경을 알리는 콜백

  const PlayerWidget({
    required this.player,
    Key?key,
    required this.music,
    required this.database,
    required this.callback,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  PlayerState? _playerState;
  Duration? _duration;   // 전체 곡 길이
  Duration? _position;   // 현재 재생 위치
  late Music _currentMusic;

  // 비동기 이벤트(재생 시간 변경 등)를 감지하는 구독 변수들
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  bool get _isPlaying => _playerState == PlayerState.playing;

  // 시간을 00:00 형식으로 변환하는 Getter
  String get _durationText => _duration?.toString().split('.').first ?? '';
  String get _positionText => _position?.toString().split('.').first ?? '';

  AudioPlayer get _player => widget.player;

  bool _repeatCheck = false;  // 반복 재생 여부
  bool _shuffleCheck = false; // 셔플 재생 여부

  @override
  void initState() {
    super.initState();
    _currentMusic = widget.music;
    _playerState = _player.state;
    _initStreams(); // 이벤트 리스너 등록

    // 초기 시간 정보 가져오기
    _player.getDuration().then((value) {
      if (mounted) setState(() => _duration = value);
    });
    _player.getCurrentPosition().then((value) {
      if (mounted) setState(() => _position = value);
    });
  }

  @override
  void dispose() {
    // 위젯이 종료될 때 스트림 구독을 해제해야 메모리 누수가 발생하지 않음
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 재생 구간 조절 슬라이더
        Slider(
          onChanged: (v) {
            // 슬라이더 이동 시 해당 위치로 seek
            final position = v * (_duration?.inMilliseconds ?? 0);
            _player.seek(Duration(milliseconds: position.round()));
          },
          value: (_position != null &&
              _duration != null &&
              _duration!.inMilliseconds > 0 &&
              _position!.inMilliseconds >= 0 &&
              _position!.inMilliseconds <= _duration!.inMilliseconds)
              ? _position!.inMilliseconds / _duration!.inMilliseconds
              : 0.0,
        ),
        // 시간 표시 (현재 / 전체)
        Text(
          _position != null
              ? '$_positionText / $_durationText'
              : _duration != null
              ? _durationText
              : '',
          style: const TextStyle(fontSize: 16.0),
        ),

        // 재생 컨트롤 버튼들 (이전, 재생/일시정지, 다음)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('prev_button'),
              onPressed: _prev,
              icon: const Icon(Icons.skip_previous),
              iconSize: 44,
              color: color,
            ),
            IconButton(
              key: const Key('play_pause_button'),
              onPressed: _isPlaying ? _pause : _play,
              iconSize: 44,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              color: color,
            ),
            IconButton(
              key: const Key('next_button'),
              onPressed: _next,
              icon: const Icon(Icons.skip_next),
              iconSize: 44,
              color: color,
            ),
          ],
        ),

        // 기능 버튼들 (반복, 셔플)
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              key: const Key('repeat_button'),
              onPressed: _repeat,
              iconSize: 44.0,
              icon: const Icon(Icons.repeat),
              color: _repeatCheck ? Colors.amberAccent : color,
            ),
            IconButton(
              key: const Key('shuffle_button'),
              onPressed: _shuffle,
              iconSize: 44.0,
              icon: const Icon(Icons.shuffle),
              color: _shuffleCheck ? Colors.amberAccent : color,
            ),
          ],
        )
      ],
    );
  }

  // 오디오 플레이어의 상태 변화를 감지하는 리스너 등록
  void _initStreams() {
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _positionSubscription = _player.onPositionChanged.listen(
          (p) => {if (mounted) setState(() => _position = p)},
    );

    // 곡이 끝났을 때의 처리
    _playerCompleteSubscription = _player.onPlayerComplete.listen((event) {
      _onCompletion();
    });
    _playerStateChangeSubscription =
        _player.onPlayerStateChanged.listen((state) {
          if (mounted) setState(() => _playerState = state);
        });
  }

  // 재생 완료 시 호출: 반복 재생이면 다시 재생, 아니면 다음 곡
  Future<void> _onCompletion() async {
    if (mounted) {
      setState(() {
        _position = _repeatCheck ? Duration.zero : _duration;
      });
    }
    if (_repeatCheck) {
      await _repeatPlay();
    } else {
      await _next();
    }
  }

  // 반복 재생 로직
  Future<void> _repeatPlay() async {
    final dir = await getApplicationDocumentsDirectory();
    if (mounted) {
      setState(() {
        _position = Duration.zero;
      });
    }
    final path = '${dir.path}/${_currentMusic.name}';
    await _player.setSourceDeviceFile(path);
    await _player.resume();
  }

  /// 재생 실행
  Future<void> _play() async {
    final player = _player;

    // [중요] 파일 경로 생성 시 객체가 아닌 파일명(.name)을 사용하도록 수정
    final currentMusicPath =
        '${(await getApplicationDocumentsDirectory()).path}/${_currentMusic.name}';

    try {
      if (player.state == PlayerState.paused) {
        await player.resume(); // 일시정지 상태면 재개
      } else {
        // 처음 재생 시 경로와 위치를 지정하여 재생
        await player.play(DeviceFileSource(currentMusicPath), position: _position);
      }
      if (mounted) {
        setState(() => _playerState = PlayerState.playing);
      }
    } catch (e) {
      print('오디오 재생 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('재생 오류: ${e.toString()}')),
        );
        setState(() => _playerState = PlayerState.stopped);
      }
    }
  }

  /// 일시정지 실행
  Future<void> _pause() async {
    try {
      await _player.pause();
      if (mounted) {
        setState(() => _playerState = PlayerState.paused);
      }
    } catch (e) {
      print('오디오 일시정지 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일시정지 오류: ${e.toString()}')),
        );
      }
    }
  }

  void _repeat() {
    if (mounted) setState(() => _repeatCheck = !_repeatCheck);
  }
  void _shuffle() {
    if (mounted) setState(() => _shuffleCheck = !_shuffleCheck);
  }

  // 이전 곡 재생
  Future<void> _prev() async {
    if (!mounted) return;

    final musics = await MusicDatabase(widget.database).getMusic();
    int currentIndex = musics.indexWhere(
            (m) => m['name'] == _currentMusic.name
    );

    if (currentIndex > 0) {
      await _playMusic(musics[currentIndex -1]);
    } else if ( currentIndex == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('첫 번째 곡입니다.')));
    } else {
      if (musics.isNotEmpty) await _playMusic(musics.first);
    }
  }

  // 다음 곡 재생
  Future<void> _next() async {
    if (!mounted) return;

    // 로컬 DB에서 전체 리스트를 가져와서 재생 목록 생성
    final List<Map<String, dynamic>> musics = await MusicDatabase(widget.database).getMusic();
    List<Map<String, dynamic>> playlist = List.from(musics);

    // 셔플 모드일 경우 리스트 섞기
    if (_shuffleCheck) {
      playlist.shuffle();
      int currentShuffledIndex = playlist.indexWhere(
              (m) => m['name'] == _currentMusic.name
      );
      // 다음 곡 로직 처리 (섞인 리스트 기준)
      if (currentShuffledIndex != -1 && currentShuffledIndex + 1< playlist.length) {
        await _playMusic(playlist[currentShuffledIndex + 1]);
      } else if (playlist.isNotEmpty && playlist.first['name'] != _currentMusic.name) {
        await _playMusic(playlist.first);
      } else if (playlist.length > 1) {
        await _playMusic(playlist[1]);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('마지막 곡입니다.')));
      }
      return;
    }

    // 일반 순차 재생
    int currentIndex = musics.indexWhere(
            (m) => m['name'] == _currentMusic.name
    );

    if (currentIndex != -1 && currentIndex + 1 < playlist.length) {
      await _playMusic(playlist[currentIndex + 1]);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('마지막 곡입니다.')));
    }
  }

  // 실제 음악 변경 및 재생 실행 함수
  Future<void> _playMusic(Map<String, dynamic> musicData) async {
    if (!mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    // 맵 데이터를 Music 객체로 변환
    _currentMusic = Music(
      musicData['name'],
      musicData['composer'],
      musicData['tag'],
      musicData['category'],
      musicData['size'],
      musicData['type'],
      musicData['downloadUrl'],
      musicData['imageDownloadUrl'],
    );
    final path = '${dir.path}/${_currentMusic.name}';

    try {
      await _player.play(DeviceFileSource(path));
      if (mounted) {
        // 부모 위젯(상세 페이지)의 UI도 업데이트
        widget.callback(_currentMusic);
        setState(() {
          _position = Duration.zero;
        });
      }
    } catch (e) {
      print('음악 재생 오류 (_playMusic): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음악 재생 오류: ${e.toString()}')),
        );
        setState(() => _playerState = PlayerState.stopped);
      }
    }
  }
}