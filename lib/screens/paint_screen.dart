import 'package:cuadro/models/custom_painter.dart';
import 'package:cuadro/models/touch_point.dart';
import 'package:cuadro/screens/home_screen.dart';
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
  TextEditingController textEditingController = TextEditingController();

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
    socket = IO.io("http://192.168.0.22:5000", <String, dynamic>{
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
        print(roomData["word"]);
        setState(() {
          dataOfRoom = roomData;
          renderTextBlank(roomData["word"]);
        });
      });

      // Not correct game
      socket.on(
          "notCorrectGame",
          (data) => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomeScreen(data: data)),
              (route) => false));

      // getting the painting on the screen
      socket.on("points", (point) {
        print(point);
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

      socket.on("msg", (messageData) {
        print(messageData);
        setState(() {
          messages.add(messageData);
        });
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
    });

    // socket.emit("test", "Hello World");
    print("hey ${socket.connected}");
  }

  @override
  void dispose() {
    socket.dispose();
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
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                width: width,
                height: height * 0.55,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    socket.emit("paint", {
                      "details": {
                        "dx": details.localPosition.dx,
                        "dy": details.localPosition.dy
                      },
                      "roomName": widget.data["name"]
                    });
                  },
                  onPanStart: (details) {
                    socket.emit("paint", {
                      "details": {
                        "dx": details.localPosition.dx,
                        "dy": details.localPosition.dy
                      },
                      "roomName": widget.data["name"]
                    });
                  },
                  onPanEnd: (details) {
                    socket.emit("paint",
                        {"details": null, "roomName": widget.data["name"]});
                  },
                  child: SizedBox.expand(
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      child: RepaintBoundary(
                        key: globalKey,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: MyCustomPainter(pointsList: points),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
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
                        socket.emit("clean-screen", widget.data["name"]);
                      }),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: textBlankWidget,
              ),
              Container(
                height: MediaQuery.of(context).size.height * 0.3,
                child: ListView.builder(
                    shrinkWrap: true,
                    primary: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      // String username = messages[index].keys.elementAt(index);
                      var msg = messages[index].values;
                      print(msg);
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
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    }),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.only(left: 20, right: 20, bottom: 30),
              child: TextField(
                controller: textEditingController,
                onSubmitted: (value) {
                  Map map = {
                    "username": widget.data["nickname"],
                    "msg": value,
                    "roomName": widget.data["name"]
                  };
                  socket.emit("msg", map);
                  textEditingController.clear();
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.transparent, width: 0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.transparent, width: 0),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        ],
      ),
    );
  }
}
