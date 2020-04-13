import 'dart:async';
import 'dart:convert';

import 'package:bujuan/api/module.dart';
import 'package:bujuan/constant/constants.dart';
import 'package:bujuan/constant/play_state.dart';
import 'package:bujuan/entity/fm_entity.dart';
import 'package:bujuan/entity/lyric_entity.dart';
import 'package:bujuan/entity/song_bean_entity.dart';
import 'package:bujuan/global_store/action.dart';
import 'package:bujuan/global_store/store.dart';
import 'package:bujuan/utils/bujuan_util.dart';
import 'package:fish_redux/fish_redux.dart';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';
import 'package:flutter_inner_drawer/inner_drawer.dart';
import '../bujuan_music.dart';
import 'action.dart';
import 'state.dart';

StreamSubscription listen;
const urlFMPlugin = const BasicMessageChannel('url_fm_plugin', StandardMessageCodec());
Effect<EntranceState> buildEffect() {
  return combineEffects(<Object, Effect<EntranceState>>{
    EntranceAction.bottomBarTap: _onBottomTap,
    EntranceAction.openPlayPage: _onOpenPlay,
    EntranceAction.sendTask: _onTask,
    EntranceAction.nextSong: _onNext,
    EntranceAction.openPage: _onOPenPage,
    Lifecycle.initState: _onInit,
    Lifecycle.dispose: _onDispose,
  });
}

void _onBottomTap(Action action, Context<EntranceState> ctx) {
  ctx.state.pageController.jumpToPage(action.payload);
}

void _onInit(Action action, Context<EntranceState> ctx) {
  listen = BujuanMusic.getStream().listen((_) {
    _onEvent(_, ctx);
  }, onError: _onError);
  urlFMPlugin.setMessageHandler((message) => Future<String>(() async{
    print(message);
    var s;
    Map map = new Map<String, String>.from(message);
    if(map['type']=='getUrl'){
      s = await _getUrl(map['id']);
      return s;
    }else{
      return s;
    }
  }));
}

void _onOpenPlay(Action action, Context<EntranceState> ctx) {
  if (ctx.state.playStateType != PlayStateType.Stop) BujuanMusic.control(task: "open");
}

void _onOPenPage(Action action, Context<EntranceState> ctx) {
  OpenType openType = action.payload;
  switch (openType) {
    case OpenType.SETTING:
      Navigator.of(ctx.context).pushNamed('setting', arguments: null);
      break;
    case OpenType.DONATION:
      Navigator.of(ctx.context).pushNamed('donation', arguments: null);
      break;
    case OpenType.ABOUT:
      Navigator.of(ctx.context).pushNamed('about', arguments: null);
      break;
  }
  ctx.state.innerDrawerKey.currentState.toggle(direction: InnerDrawerDirection.start);
//  Future.delayed(Duration(milliseconds: 200), () {
//  });
}

void _onTask(Action action, Context<EntranceState> ctx) {
  if (ctx.state.playStateType != PlayStateType.Stop) BujuanMusic.control(task: ctx.state.playStateType == PlayStateType.Playing ? 'pause' : 'play');
}

void _onNext(Action action, Context<EntranceState> ctx) {
  if (ctx.state.playStateType != PlayStateType.Stop) BujuanMusic.control(task: 'next');
}

void _onDispose(Action action, Context<EntranceState> ctx) {
  listen?.cancel();
  ctx.state.pageController?.dispose();
  ctx.state.controller?.dispose();
}

//原生播放状态返回
void _onEvent(Object event, ctx) {
  Map<String, dynamic> tag = Map<String, dynamic>.from(event);
  var currSong = tag['currSong'];
  var state = tag['state'];
  if (currSong != null) {
    SongBeanEntity songBeanEntity = SongBeanEntity.fromJson(jsonDecode(currSong));
    _getLyric(songBeanEntity.id).then((lyric) {
      GlobalStore.store.dispatch(GlobalActionCreator.changeLyric(lyric));
    });
    GlobalStore.store.dispatch(GlobalActionCreator.changeCurrSong(songBeanEntity));
  }

  if (state != null) {
    ///执行了暂停，播放等操作
    PlayStateType playState;
    if (state == 'start') {
      playState = PlayStateType.Playing;
    } else if (state == 'pause') {
      playState = PlayStateType.Pause;
    } else if (state == 'stop') {
      playState = PlayStateType.Stop;
    } else if (state == 'completion') {
//      var fm = SpUtil.getBool(Constants.ISFM, defValue: false);
//      if (fm) {
//        BujuanMusic.control(task: 'stop');
//        _getFm().then((fm) {
//          List<SongBeanEntity> songs = List();
//          fm.data.forEach((data) {
//            SongBeanEntity songBeanEntity = SongBeanEntity();
//            songBeanEntity.id = data.id.toString();
//            songBeanEntity.name = data.name;
//            songBeanEntity.singer = data.artists[0].name;
//            songBeanEntity.picUrl = data.album.picUrl;
//            songBeanEntity.mv = data.mvid;
//            songs.add(songBeanEntity);
//          });
//
//          GlobalStore.store
//              .dispatch(GlobalActionCreator.changeCurrSong(songs[0]));
//          SpUtil.putObjectList(Constants.playSongListHistory, songs);
//          var jsonEncode2 = jsonEncode(songs);
//          BujuanMusic.sendSongInfo(
//              songInfo: jsonEncode2, playSong: jsonEncode(songs[0]));
//        });
//      }
      GlobalStore.store.dispatch(GlobalActionCreator.changeSongPos(0));
      GlobalStore.store.dispatch(GlobalActionCreator.changeSongAllPos(100));
    }

    GlobalStore.store.dispatch(GlobalActionCreator.changePlayState(playState));
  }

  ///歌曲进度
//  if (pos != null) {
//    println('=====POSITION===$pos');
//    GlobalStore.store.dispatch(GlobalActionCreator.changeSongPos(int.parse(pos)));
//  }
//
//  if(allPos!=null){
//    GlobalStore.store.dispatch(GlobalActionCreator.changeSongAllPos(int.parse(allPos)));
//  }
}

//获取播放状态异常
void _onError(Object error) {
  print('===_onError=========================$error');
}

Future<LyricEntity> _getLyric(id) async {
  var answer = await lyric({'id': id}, BuJuanUtil.getCookie());
  if (answer.status == 200 && answer.body != null) {
    return LyricEntity.fromJson(answer.body);
  } else
    return null;
}

//获取播放地址
Future<String> _getUrl(id) async{
  var answer = await song_url({'id':id,'br':'320000'},BuJuanUtil.getCookie());
  if (answer.status == 200 && answer.body != null) {
    var body = answer.body['data'][0]['url'];
    return body;
  } else
    return null;
}
///personal_fm
Future<FmEntity> _getFm() async {
//  Response sheet = await HttpUtil().get('/personal_fm');
//  var data = sheet.data;
//  var jsonDecode2 = jsonDecode(data);
//  return FmEntity.fromJson(jsonDecode2);
}
