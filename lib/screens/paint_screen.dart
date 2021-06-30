import 'dart:async';

import 'package:cuadro/models/custom_painter.dart';
import 'package:cuadro/models/touch_point.dart';
import 'package:cuadro/screens/home_screen.dart';
import 'package:cuadro/sidebar/player_score_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class PaintScreen extends StatefulWidget {
  final Map data;
  final String screenFrom;
  PaintScreen({this.data, this.screenFrom});
  @override
  _PaintScreenState createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  GlobalKey globalKey = GlobalKey();
  List<TouchPoints> points = [];
  double opacity = 1.0;
  StrokeCap strokeType = StrokeCap.round;
  Color selectedColor;
  double strokeWidth;
  IO.Socket socket;
  Map dataOfRoom;
  List<Widget> textBlankWidget = [];
  List<Map> messages = [];
  List<Map> scoreboard = [];
  TextEditingController textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  var focusNode = FocusNode();
  var scaffoldKey = GlobalKey<ScaffoldState>();
  bool isTextInputReadOnly = false;

  Timer _timer;
  int _start = 30;
  int roundTime = 30;
  int guessedUserCtr = 0;

  // round time -> 30 sec
  // waiting -> until room.players === room.occupancy
  // select word -> 10 sec

  void startTimer() {
    const oneSec = const Duration(seconds: 1);
    _timer = new Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    connect();
    selectedColor = Colors.black;
    strokeWidth = 2.0;
  }

  void renderTextBlank(String text) {
    textBlankWidget.clear();
    for (int i = 0; i < text.length; i++) {
      textBlankWidget.add(Text(
        "_",
        style: TextStyle(fontSize: 30),
      ));
    }
  }

  void connect() {
    socket = IO.io("http://192.168.43.110:5000", <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false,
    });
    socket.connect();
    if (widget.screenFrom == "createRoom") {
      // creating room
      socket.emit("create-game", widget.data);
    } else {
      // joining room
      socket.emit("join-game", widget.data);
    }
    socket.onConnect((data) {
      print("connected");
      socket.on("updateRoom", (roomData) {
        setState(() {
          renderTextBlank(roomData["word"]);
          dataOfRoom = roomData;
        });
        if (roomData["isJoin"] != true) {
          // started timer as game started
          startTimer();
        }
        scoreboard.clear();
        for (int i = 0; i < roomData["players"].length; i++) {
          setState(() {
            scoreboard.add({
              "username": roomData["players"][i]["nickname"],
              "points": roomData["players"][i]["points"].toString()
            });
          });
        }
      });

      // updating scoreboard
      socket.on("updateScore", (roomData) {
        scoreboard.clear();
        for (int i = 0; i < roomData["players"].length; i++) {
          setState(() {
            scoreboard.add({
              "username": roomData["players"][i]["nickname"],
              "points": roomData["players"][i]["points"].toString()
            });
          });
        }
      });

      // Not correct game
      socket.on(
          "notCorrectGame",
          (data) => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomeScreen(data: data)),
              (route) => false));

      // getting the painting on the screen
      socket.on("points", (point) {
        if (point["details"] != null) {
          setState(() {
            points.add(
              TouchPoints(
                  points: Offset((point["details"]["dx"]).toDouble(),
                      (point["details"]["dy"]).toDouble()),
                  paint: Paint()
                    ..strokeCap = strokeType
                    ..isAntiAlias = true
                    ..color = selectedColor.withOpacity(opacity)
                    ..strokeWidth = strokeWidth),
            );
          });
        } else {
          setState(() {
            points.add(null);
          });
        }
      });

      socket.on("closeInput", (_) {
        socket.emit("updateScore", widget.data["name"]);
        FocusScope.of(context).unfocus();
        setState(() {
          isTextInputReadOnly = true;
        });
      });

      socket.on("change-turn", (data) {
        String oldeWord = dataOfRoom["word"];
        print(oldeWord);
        showDialog(
            context: scaffoldKey.currentContext,
            barrierDismissible: false,
            builder: (context) {
              Future.delayed(Duration(seconds: 3), () {
                Navigator.of(context).pop(true);
                setState(() {
                  dataOfRoom = data;
                  renderTextBlank(data["word"]);
                  isTextInputReadOnly = false;
                  _start = 30;
                  guessedUserCtr = 0;
                });
                // cancelling the before timer
                _timer.cancel();
                startTimer();
              });
              return AlertDialog(
                title: Center(child: Text("Word was $oldeWord")),
              );
            });
      });

      socket.on("msg", (messageData) {
        setState(() {
          messages.add(messageData);
          guessedUserCtr = messageData["guessedUserCtr"];
        });
        if (guessedUserCtr == dataOfRoom["players"].length - 1) {
          // length-1 because we dont have to include the host to guess.
          // next round
          socket.emit("change-turn", dataOfRoom["name"]);
        }
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 40,
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut);
      });

      // changing stroke width of pen
      socket.on(
          "stroke-width",
          (stroke) => this.setState(() {
                strokeWidth = stroke;
              }));

      // clearing off the screen with clean button
      socket.on(
          "clear-screen",
          (data) => this.setState(() {
                points.clear();
              }));

      // disconnect socket
      socket.onDisconnect((_) => print('disconnectted'));
    });

    // socket.emit("test", "Hello World");
    print("hey ${socket.connected}");
  }

  @override
  void dispose() {
    socket.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    void selectColor() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Color Chooser'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) {
                this.setState(() {
                  selectedColor = color;
                });
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("Close"))
          ],
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      drawer: PlayerScore(scoreboard),
      backgroundColor: Colors.white,
      body: dataOfRoom != null
          ? dataOfRoom["isJoin"] != true
              ? Stack(
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: width,
                          height: height * 0.55,
                          child: GestureDetector(
                            onPanUpdate: dataOfRoom["turn"]["nickname"] ==
                                    widget.data["nickname"]
                                ? (details) {
                                    socket.emit("paint", {
                                      "details": {
                                        "dx": details.localPosition.dx,
                                        "dy": details.localPosition.dy
                                      },
                                      "roomName": widget.data["name"]
                                    });
                                  }
                                : (_) {},
                            onPanStart: dataOfRoom["turn"]["nickname"] ==
                                    widget.data["nickname"]
                                ? (details) {
                                    socket.emit("paint", {
                                      "details": {
                                        "dx": details.localPosition.dx,
                                        "dy": details.localPosition.dy
                                      },
                                      "roomName": widget.data["name"]
                                    });
                                  }
                                : (_) {},
                            onPanEnd: dataOfRoom["turn"]["nickname"] ==
                                    widget.data["nickname"]
                                ? (details) {
                                    socket.emit("paint", {
                                      "details": null,
                                      "roomName": widget.data["name"]
                                    });
                                  }
                                : (_) {},
                            child: SizedBox.expand(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20.0)),
                                child: RepaintBoundary(
                                  key: globalKey,
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter:
                                        MyCustomPainter(pointsList: points),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        dataOfRoom["turn"]["nickname"] ==
                                widget.data["nickname"]
                            ? Row(
                                children: <Widget>[
                                  IconButton(
                                      icon: Icon(
                                        Icons.color_lens,
                                        color: selectedColor,
                                      ),
                                      onPressed: () {
                                        selectColor();
                                      }),
                                  Expanded(
                                    child: Slider(
                                      min: 1.0,
                                      max: 10.0,
                                      label: "Stroke $strokeWidth",
                                      activeColor: selectedColor,
                                      value: strokeWidth,
                                      onChanged: (double value) {
                                        socket.emit("stroke-width", value);
                                      },
                                    ),
                                  ),
                                  IconButton(
                                      icon: Icon(
                                        Icons.layers_clear,
                                        color: Colors.black,
                                      ),
                                      onPressed: () {
                                        socket.emit("clean-screen",
                                            widget.data["name"]);
                                      }),
                                ],
                              )
                            : Center(
                                child: Text(
                                  "${dataOfRoom["turn"]["nickname"]} is drawing..",
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                        dataOfRoom["turn"]["nickname"] !=
                                widget.data["nickname"]
                            ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: textBlankWidget,
                              )
                            : Center(
                                child: Text(
                                  dataOfRoom["word"],
                                  style: TextStyle(fontSize: 30),
                                ),
                              ),
                        Container(
                          height: MediaQuery.of(context).size.height * 0.3,
                          child: ListView.builder(
                              controller: _scrollController,
                              shrinkWrap: true,
                              // primary: true,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                var msg = messages[index].values;
                                return ListTile(
                                  title: Text(
                                    msg.elementAt(0),
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    msg.elementAt(1),
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 16),
                                  ),
                                );
                              }),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: EdgeInsets.only(left: 20, right: 20),
                        child: TextField(
                          readOnly: isTextInputReadOnly,
                          autocorrect: false,
                          focusNode: focusNode,
                          controller: textEditingController,
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              Map map = {
                                "username": widget.data["nickname"],
                                "msg": value.trim(),
                                "word": dataOfRoom["word"],
                                "roomName": widget.data["name"],
                                "totalTime": roundTime,
                                "timeTaken": roundTime - _start,
                                "guessedUserCtr": guessedUserCtr
                              };
                              socket.emit("msg", map);
                              textEditingController.clear();
                              FocusScope.of(context).requestFocus(focusNode);
                            }
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors.transparent, width: 0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors.transparent, width: 0),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            filled: true,
                            fillColor: Color(0xffF5F6FA),
                            hintText: "Your guess",
                            hintStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: Colors.black,
                        ),
                        onPressed: () => scaffoldKey.currentState.openDrawer(),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Text(
                      "Waiting for ${dataOfRoom["occupancy"] - dataOfRoom["players"].length} players to join"),
                )
          : Center(
              child: CircularProgressIndicator(),
            ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(
          bottom: 30,
        ),
        child: FloatingActionButton(
          onPressed: () {},
          elevation: 7,
          backgroundColor: Colors.white,
          child: Text(
            "$_start",
            style: TextStyle(color: Colors.black, fontSize: 22),
          ),
        ),
      ),
    );
  }
}
