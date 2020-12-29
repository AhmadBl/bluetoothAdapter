import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:bluetoothadapter/bluetoothadapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:async/async.dart';
import 'package:downloads_path_provider/downloads_path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Bluetoothadapter flutterbluetoothadapter = Bluetoothadapter();
  StreamSubscription _btConnectionStatusListener, _btReceivedMessageListener;
  String _connectionStatus = "NONE";
  List<BtDevice> devices = [];
  String _recievedMessage;
  TextEditingController _controller = TextEditingController();

  List<List<int>> chunks = <List<int>>[];
  int contentLength = 0;
  Uint8List _bytes;

  RestartableTimer _timer;

  @override
  void initState() {
    super.initState();
    flutterbluetoothadapter
        .initBlutoothConnection("20585adb-d260-445e-934b-032a2c8b2e14");
    flutterbluetoothadapter
        .checkBluetooth()
        .then((value) => print(value.toString()));
    _startListening();
    _timer = new RestartableTimer(Duration(seconds: 1), _drawImage);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  _startListening() {
    _btConnectionStatusListener =
        flutterbluetoothadapter.connectionStatus().listen((dynamic status) {
      setState(() {
        _connectionStatus = status.toString();
      });
    });
    _btReceivedMessageListener = flutterbluetoothadapter
        .receiveMessages()
        .listen((dynamic newMessage) async {
      List<int> list = newMessage.codeUnits;
      Uint8List data = Uint8List.fromList(list);

      if (data != null && data.length > 0) {
        chunks.add(data);
        contentLength += data.length;
        _timer.reset();
      }
      print("DataLength: ${data.length}, chunks: ${chunks.length}");
    });
  }

  _drawImage() async {
    if (chunks.length == 0 || contentLength == 0) return;

    _bytes = Uint8List(contentLength);
    int offset = 0;
    for (final List<int> chunk in chunks) {
      _bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    Directory appDocumentsDirectory = await getApplicationDocumentsDirectory(); 
    String appDocumentsPath = appDocumentsDirectory.path; 
    var downloadsDirectory = await DownloadsPathProvider.downloadsDirectory;
    String filePath = downloadsDirectory.path + '/picture.jpg'; 
    File file = File(filePath);
    file.writeAsBytes(_bytes, mode: FileMode.write); 

    setState(() {});

    contentLength = 0;
    chunks.clear();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  fit: FlexFit.tight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      onPressed: () async {
                        await flutterbluetoothadapter.startServer();
                      },
                      child: Text('LISTEN'),
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.tight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      onPressed: () {
                        contentLength = 0;
                        chunks.clear();
                        print("Erase done.........");
                        _timer.cancel();
                      },
                      child: Text('Erase'),
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.tight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      onPressed: () async {
                        devices = await flutterbluetoothadapter.getDevices();
                        setState(() {});
                      },
                      child: Text('LIST DEVICES'),
                    ),
                  ),
                )
              ],
            ),
            Text("STATUS - $_connectionStatus"),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 20,
              ),
              child: ListView(
                shrinkWrap: true,
                children: _createDevices(),
              ),
            ),
            Text(
              _recievedMessage ?? "NO MESSAGE",
              style: TextStyle(fontSize: 24),
            ),
            Row(
              children: <Widget>[
                Flexible(
                  flex: 4,
                  fit: FlexFit.tight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(hintText: "Write message"),
                    ),
                  ),
                ),
                _bytes != null
                    ? Image.memory(_bytes, fit: BoxFit.fitWidth)
                    : Container(),
                Flexible(
                  fit: FlexFit.tight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                      onPressed: () {
                        flutterbluetoothadapter.sendMessage(
                            _controller.text ?? "no msg",
                            sendByteByByte: false);
//                        flutterbluetoothadapter.sendMessage(".",
//                            sendByteByByte: true);
                        _controller.text = "";
                      },
                      child: Text('SEND'),
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  _createDevices() {
    if (devices.isEmpty) {
      return [
        Center(
          child: Text("No Paired Devices listed..."),
        )
      ];
    }
    List<Widget> deviceList = [];
    devices.forEach((element) {
      deviceList.add(
        InkWell(
          key: UniqueKey(),
          onTap: () {
            flutterbluetoothadapter.startClient(devices.indexOf(element), true);
          },
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(border: Border.all()),
            child: Text(
              element.name.toString(),
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    });
    return deviceList;
  }

  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Future<Directory> downloadsDirectory =
      DownloadsPathProvider.downloadsDirectory;
}
