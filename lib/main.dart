import 'dart:async';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sonaplay/app.dart';
import 'package:sonaplay/core/presentation/update_dialog.dart';
import 'package:sonaplay/features/library/data/models/favorite_model.dart';
import 'package:sonaplay/features/library/data/models/hidden_songs_model.dart';
import 'package:sonaplay/features/library/data/models/playlist_model.dart';
import 'package:sonaplay/features/library/data/models/song_model.dart';
import 'package:sonaplay/features/player/data/datasources/audio_player_datasource.dart';
import 'package:sonaplay/features/player/data/datasources/playback_persistence_datasource.dart';
import 'package:sonaplay/features/player/data/services/audio_handler.dart';
import 'package:sonaplay/firebase_options.dart';

/// Global AudioHandler instance
late SonaPlayAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await Hive.initFlutter();
  Hive.registerAdapter(FavoriteModelAdapter());
  Hive.registerAdapter(PlaylistModelAdapter());
  Hive.registerAdapter(HiddenSongsModelAdapter());
  Hive.registerAdapter(SongModelAdapter());
  await Hive.openBox<FavoriteModel>('favorites');
  await Hive.openBox<PlaylistModel>('playlists');
  await Hive.openBox<SongModel>('cached_songs');
  await Hive.openBox('settings_box');
  await Hive.openBox('playback_settings_box');
  await Hive.openBox('play_counts');

  // Foreground service that survives the app being removed from Recents
  audioHandler = await AudioService.init(
    builder: () => SonaPlayAudioHandler(
      AudioPlayerDataSource(PlaybackPersistenceDataSource()),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sonaplay.audio',
      androidNotificationChannelName: 'SonaPlay',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true, // required with ongoing notification
      androidNotificationIcon: 'drawable/ic_notification',
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (kProfileMode) _logFrameTimes();
  runApp(const ProviderScope(child: SonaPlayApp()));
  // In the background: the fetch can take seconds and must not delay startup
  unawaited(checkForRequiredUpdate(appNavigatorKey));
}

/// Profile builds only: every 120 frames, logs how long they took, to find
/// jank on a real phone (adb logcat | grep frames)
void _logFrameTimes() {
  final frames = <FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback((timings) {
    frames.addAll(timings);
    if (frames.length < 120) return;
    double ms(Duration d) => d.inMicroseconds / 1000;
    final build = frames.map((f) => ms(f.buildDuration)).toList()..sort();
    final raster = frames.map((f) => ms(f.rasterDuration)).toList()..sort();
    final slow = frames.where((f) => ms(f.totalSpan) > 16.7).length;
    debugPrint(
      'frames: build avg ${(build.reduce((a, b) => a + b) / build.length).toStringAsFixed(1)} '
      'p99 ${build[(build.length * 0.99).floor()].toStringAsFixed(1)} · '
      'raster avg ${(raster.reduce((a, b) => a + b) / raster.length).toStringAsFixed(1)} '
      'p99 ${raster[(raster.length * 0.99).floor()].toStringAsFixed(1)} · '
      'over 16.7 ms: $slow/${frames.length}',
    );
    frames.clear();
  });
}
