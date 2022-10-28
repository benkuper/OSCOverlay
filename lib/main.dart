import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_overlay_apps/flutter_overlay_apps.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:osc/osc.dart';
import 'package:video_player/video_player.dart';
import 'package:vibration/vibration.dart';
import 'package:path_provider/path_provider.dart';
class OverlayCommand {
  String command;
  dynamic data;

  OverlayCommand(this.command, this.data);
  OverlayCommand.fromJson(Map<String, dynamic> json)
      : command = json['command'],
        data = json['data'];

  Map<String, dynamic> toJson() => {
        'command': command,
        'data': data,
      };
}

void main() {
  runApp(MyApp());
}

// overlay entry point
@pragma("vm:entry-point")
void showOverlay() {
  runApp(const MaterialApp(
      color: Colors.transparent,
      debugShowCheckedModeBanner: false,
      home: MyOverlayContent()));
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final osc = OSCSocket(serverPort: 9000);

  Directory? libDir;
  String ip = "[not found]";

  @override
  void initState() {
    super.initState();
    osc.listen(onOSCData);

    getIp();

    WidgetsFlutterBinding.ensureInitialized();
    getExternalStorageDirectory().then((value) {
      libDir = value;
      setState(() {});
    });
  }

  void getIp() async
  {
    NetworkInfo().getWifiIP().
  }

  void onOSCData(msg) async {
    switch (msg.address) {
      case "/vibrate":
        print("Vibrate " + msg.arguments[0].toString());
        Vibration.vibrate(
            duration: ((msg.arguments[0] as double) * 1000).round());
        break;

      case "/play":
        print("Play media " + msg.arguments[0].toString());
        try {
          FlutterOverlayApps.showOverlay(alignment: OverlayAlignment.topLeft);
          await Future.delayed(const Duration(milliseconds: 20));

          bool loop =
              msg.arguments.length > 1 ? msg.arguments[1].toBool() : false;
          double start =
              msg.arguments.length > 2 ? msg.arguments[2].toDouble() : 0;
          bool end =
              msg.arguments.length > 3 ? msg.arguments[3].toDouble() : -1;

          Object data = {
            "file": msg.arguments[0]?.toString(),
            "loop": loop,
            "start": start,
            "end": end
          };

          FlutterOverlayApps.sendDataToAndFromOverlay(
              jsonEncode(OverlayCommand("play", data)));
        } on Exception catch (_) {
          print("Error launching video");
        }

        break;

      case "/stop":
        print("Stop media");

        FlutterOverlayApps.sendDataToAndFromOverlay(
            jsonEncode(OverlayCommand("stop", "")));
        break;

      case "/color":
        FlutterOverlayApps.showOverlay(alignment: OverlayAlignment.topLeft);
        await Future.delayed(const Duration(milliseconds: 20));
        var c = Color.fromARGB(255, (msg.arguments[0] * 255).toInt(),
            (msg.arguments[1] * 255).toInt(), (msg.arguments[2] * 255).toInt());

        print("Set BG Color 0x" + c.toString());

        FlutterOverlayApps.sendDataToAndFromOverlay(
            jsonEncode(OverlayCommand("color", c.value)));
        break;

      case "/text":
        FlutterOverlayApps.showOverlay(alignment: OverlayAlignment.topLeft);
        await Future.delayed(const Duration(milliseconds: 20));

        var t = msg.arguments[0].toString();
        var size = msg.arguments.length > 1 ? msg.arguments[1].toDouble() : 30;
        var tc = msg.arguments.length > 2
            ? Color.fromARGB(
                255,
                (msg.arguments[2] * 255).toInt(),
                (msg.arguments[3] * 255).toInt(),
                (msg.arguments[4] * 255).toInt())
            : Colors.white;
        var bc = msg.arguments.length > 5
            ? Color.fromARGB(
                255,
                (msg.arguments[5] * 255).toInt(),
                (msg.arguments[6] * 255).toInt(),
                (msg.arguments[7] * 255).toInt())
            : Colors.black;

        FlutterOverlayApps.sendDataToAndFromOverlay(jsonEncode(OverlayCommand(
            "text", {
          "text": t,
          "fontSize": size,
          "textColor": tc.value,
          "bgColor": bc.value
        })));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          MoveToBackground.moveTaskToBack();
          return false;
        },
        child: MaterialApp(
          color: Colors.white24,
          home: Scaffold(
              appBar: AppBar(
                title: const Text('OSC Overlay'),
              ),
              body: Center(
                  child: Column(children: [
                Padding(
                  padding: EdgeInsets.all(50),
                  child: Text(
                      "Commands :\n\n/play <file.ext> (mp3, mp4, wav...) [loop (0/1), start(0-... seconds), end(0-...)]\n\n/play <url> (http://192.168.1.10/file.mp4) [loop (0/1), start(0-... seconds), end(0-...)]" +
                          "\n\n/stop\n\n/vibrate <time> (seconds)\n\n/color <r> <g> <b> (floats)\n\n/text <text> [<fontSize> <textColor r g b> <bgColor r g b>]\n\n\n\n" +
                          "Local files should be placed in \n" +
                          (libDir != null ? libDir!.path : "")),
                ),
                Padding(
                    padding: EdgeInsets.all(50),
                    child: ElevatedButton(
                        onPressed: () {
                          MoveToBackground.moveTaskToBack();
                        },
                        child: const Text("Close"))),
              ]))),
        ));
  }
}

class MyOverlayContent extends StatefulWidget {
  const MyOverlayContent({Key? key}) : super(key: key);

  @override
  State<MyOverlayContent> createState() => _MyOverlayContentState();
}

class _MyOverlayContentState extends State<MyOverlayContent> {
  late VideoPlayerController? player;

  Color bgColor = Colors.black;
  String text = "";
  double fontSize = 30;
  Color textColor = Colors.white;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    player = null;
    // lisent for any data from the main app
    FlutterOverlayApps.overlayListener().listen((event) {
      Map<String, dynamic> c = jsonDecode(event);
      handleCommand(c).then((value) {
        setState(() {});
      });
    });
  }

  Future handleCommand(c) async {
    String command = c["command"];

    //init all content
    if (player != null) {
      player!.pause();
    }
    text = "";
    bgColor = Colors.black;
    fontSize = 30;
    textColor = Colors.white;

    isPlaying = false;

    switch (command) {
      case "play":
      case "playAt":
        {
          print("play : ");
          isPlaying = true;

          Directory? libDir = await getExternalStorageDirectory();

          var filename = c["data"]["file"].toString();
          if (filename.startsWith("http")) {
            player = VideoPlayerController.network(filename);
          } else {
            File f = File(libDir!.path + "/$filename");
            player = VideoPlayerController.file(f);
          }

          bool loop = c["data"]["loop"];
          double start = c["data"]["start"];
          double end = c["data"]["end"];


          if (start > 0)
            player!.seekTo(Duration(milliseconds: (start * 1000).toInt()));

          player!.addListener(() {
            setState(() {});
            if(end > start) player?.position.then((value) => checkPos(value, start, end, loop));
          });

          try {
            player!.initialize().then((_) => setState(() {}));
            player!.setLooping(loop);
            player!.play();
          } on Exception catch (_) {
            print("Error playing video, probably intent problem");
          }
        }


        break;

      case "stop":
        FlutterOverlayApps.closeOverlay();
        break;

      case "color":
        bgColor = Color(c["data"]);

        break;

      case "text":
        var d = c["data"];
        text = d["text"];
        fontSize = d["fontSize"];
        textColor = Color(d["textColor"]);
        bgColor = Color(d["bgColor"]);
        break;
    }
  }
  
  void checkPos(pos, start, end, loop)
  {
    if(pos > end)
    {
      if(loop) player?.seekTo(start) ;
      else player?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        child: InkWell(
            onDoubleTap: () {
              // close overlay
              if (player != null) {
                player!.pause();
                // player!.dispose();
              }
              FlutterOverlayApps.closeOverlay();
            },
            child: Stack(children: [
              Container(
                  color: bgColor,
                  child: (player != null && isPlaying)
                      ? VideoPlayer(player!)
                      : null),
              Center(
                  child: Text(text,
                      style: TextStyle(color: textColor, fontSize: fontSize)))
            ])));
  }
}
