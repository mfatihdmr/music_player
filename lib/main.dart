import 'dart:math';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MusicPlayerScreen(),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  @override
  _MusicPlayerScreenState createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _musicFiles = [];
  List<String> _favoriteMusicFiles = [];
  List<String> _selectedMusicFiles = [];
  int _currentIndex = 0;
  bool isPlaying = false;
  bool isPickingFiles = false;
  bool isShuffle = false;
  bool isSelectionMode = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String _currentSong = '';

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _loadMusicFiles();
    _loadFavoriteMusicFiles();
    
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.completed) {
        _playNext();
      }
    });
  }

  Future<void> _requestPermission() async {
    await Permission.storage.request();
  }

  Future<void> _pickFiles() async {
    if (isPickingFiles) return;

    setState(() {
      isPickingFiles = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null) {
        List<String> paths = result.paths.map((path) => path!).toList();
        setState(() {
          _musicFiles = paths;
        });
        _saveMusicFiles(paths);
      }
    } finally {
      setState(() {
        isPickingFiles = false;
      });
    }
  }

  Future<void> _saveMusicFiles(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('musicFiles', paths);
  }

  Future<void> _loadMusicFiles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicFiles = prefs.getStringList('musicFiles') ?? [];
    });
  }

  Future<void> _loadFavoriteMusicFiles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteMusicFiles = prefs.getStringList('favoriteMusicFiles') ?? [];
    });
  }

  Future<void> _saveFavoriteMusicFiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteMusicFiles', _favoriteMusicFiles);
  }

  void _playMusic(int index) {
    if (index < 0 || index >= _musicFiles.length) return;

    _audioPlayer.play(DeviceFileSource(_musicFiles[index]));
    setState(() {
      _currentIndex = index;
      _currentSong = _musicFiles[index].split('/').last;
      isPlaying = true;
    });
  }

  void _playMusicFile(String filePath) {
    int index = _musicFiles.indexOf(filePath);
    if (index != -1) {
      _playMusic(index);
    } else {
      setState(() {
        _musicFiles.add(filePath);
        _playMusic(_musicFiles.length - 1);
      });
    }
  }

  void _pauseMusic() {
    _audioPlayer.pause();
    setState(() {
      isPlaying = false;
    });
  }

  void _playNext() {
    if (_musicFiles.isEmpty) return;

    if (isShuffle) {
      int nextIndex;
      do {
        nextIndex = Random().nextInt(_musicFiles.length);
      } while (nextIndex == _currentIndex);
      _playMusic(nextIndex);
    } else {
      if (_currentIndex + 1 < _musicFiles.length) {
        _playMusic(_currentIndex + 1);
      } else {
        // Optionally, loop to the beginning or stop playback when the list ends
        _playMusic(0);
      }
    }
  }

  void _playPrevious() {
    if (_currentIndex - 1 >= 0) {
      _playMusic(_currentIndex - 1);
    }
  }

  void _toggleShuffle() {
    setState(() {
      isShuffle = !isShuffle;
    });
  }

  void _seekTo(Duration position) {
    _audioPlayer.seek(position);
  }

  void _toggleFavorite(String filePath) {
    setState(() {
      if (_favoriteMusicFiles.contains(filePath)) {
        _favoriteMusicFiles.remove(filePath);
      } else {
        _favoriteMusicFiles.add(filePath);
      }
      _saveFavoriteMusicFiles();
    });
  }

  void _removeSelectedMusicFiles() {
    setState(() {
      _musicFiles.removeWhere((file) => _selectedMusicFiles.contains(file));
      _favoriteMusicFiles
          .removeWhere((file) => _selectedMusicFiles.contains(file));
      _selectedMusicFiles.clear();
      isSelectionMode = false;
      _saveMusicFiles(_musicFiles);
      _saveFavoriteMusicFiles();
    });
  }

  void _selectAllMusicFiles() {
    setState(() {
      if (_selectedMusicFiles.length == _musicFiles.length) {
        _selectedMusicFiles.clear();
      } else {
        _selectedMusicFiles = List.from(_musicFiles);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      _selectedMusicFiles.clear();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Music Player'),
        actions: [
          IconButton(
            icon: Icon(Icons.folder_open),
            onPressed: _pickFiles,
          ),
          if (isSelectionMode)
            IconButton(
              icon: Icon(Icons.select_all),
              onPressed: _selectAllMusicFiles,
            ),
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavoritesScreen(
                    favoriteMusicFiles: _favoriteMusicFiles,
                    onPlayMusic: _playMusicFile,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentSong.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Şu An Çalıyor: $_currentSong',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _musicFiles.length,
              itemBuilder: (context, index) {
                final filePath = _musicFiles[index];
                final isFavorite = _favoriteMusicFiles.contains(filePath);
                final isSelected = _selectedMusicFiles.contains(filePath);
                final isCurrentPlaying = _currentIndex == index;
                return ListTile(
                  title: Text(filePath.split('/').last),
                  tileColor: isCurrentPlaying ? Colors.deepPurple[100] : null,
                  leading: isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedMusicFiles.add(filePath);
                              } else {
                                _selectedMusicFiles.remove(filePath);
                              }
                            });
                          },
                        )
                      : null,
                  trailing: isSelectionMode
                      ? null
                      : IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : null,
                          ),
                          onPressed: () => _toggleFavorite(filePath),
                        ),
                  onTap: () {
                    if (isSelectionMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedMusicFiles.remove(filePath);
                        } else {
                          _selectedMusicFiles.add(filePath);
                        }
                      });
                    } else {
                      if (isPlaying && _currentIndex == index) {
                        _pauseMusic();
                      } else {
                        _playMusic(index);
                      }
                    }
                  },
                  onLongPress: () {
                    _toggleSelectionMode();
                  },
                );
              },
            ),
          ),
          if (isSelectionMode)
            ElevatedButton(
              onPressed: _removeSelectedMusicFiles,
              child: Text('Seçilenleri Kaldır'),
            ),
          if (_musicFiles.isNotEmpty)
            Column(
              children: [
                Slider(
                  value: _currentPosition.inSeconds.toDouble(),
                  min: 0.0,
                  max: _totalDuration.inSeconds.toDouble(),
                  onChanged: (value) {
                    _seekTo(Duration(seconds: value.toInt()));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.shuffle),
                        onPressed: _toggleShuffle,
                        color: isShuffle ? Colors.deepPurple : Colors.black,
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_previous),
                        onPressed: _playPrevious,
                      ),
                      FloatingActionButton(
                        onPressed: isPlaying
                            ? _pauseMusic
                            : () => _playMusic(_currentIndex),
                        child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next),
                        onPressed: _playNext,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  final List<String> favoriteMusicFiles;
  final Function(String) onPlayMusic;

  FavoritesScreen(
      {required this.favoriteMusicFiles, required this.onPlayMusic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favoriler'),
      ),
      body: FutureBuilder<List<String>>(
        future: _loadFavoriteMusicFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Favori müzik bulunmuyor'));
          }

          final favoriteMusicFiles = snapshot.data!;
          return ListView.builder(
            itemCount: favoriteMusicFiles.length,
            itemBuilder: (context, index) {
              final filePath = favoriteMusicFiles[index];
              return ListTile(
                title: Text(filePath.split('/').last),
                onTap: () {
                  onPlayMusic(filePath);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<String>> _loadFavoriteMusicFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('favoriteMusicFiles') ?? [];
  }
}
