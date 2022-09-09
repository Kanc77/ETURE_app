// @dart=2.9

import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ETURE',
      theme: ThemeData(

        primarySwatch: Colors.green,
        textTheme: const TextTheme(
          headline1: TextStyle(color: Colors.green),
          headline2: TextStyle(color: const Color(0x15B946)),
          headline3: TextStyle(color: Colors.white),
        ),
      ),
      home: BleScanPage(title: 'ETURE zaklenilnica'),
    );
  }
}

class BleScanPage extends StatefulWidget {
  BleScanPage({Key key, this.title}) : super(key: key);

  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = new List<BluetoothDevice>();
  final Map<Guid, List<int>> readValues = new Map<Guid, List<int>>();

  @override
  State<BleScanPage> createState() => _BleScanPageState();
}

class _BleScanPageState extends State<BleScanPage> {

  BluetoothDevice _connectedDevice;
  List<BluetoothService> _services;

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  _scanForBleDevs(){
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }

  ListView _buildListViewOfDevices() {
    List<Container> containers = new List<Container>();
    for (BluetoothDevice device in widget.devicesList) {
      containers.add(
        Container(
          height: 65,
          width:20,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(device.name == '' ? '(neznana naprava)' : device.name),
                    Text(device.id.toString()),
                  ],
                ),
              ),
              SizedBox(
                width: 80.0,
                height: 30.0,
                child: ElevatedButton(
                  child: Text(
                    'Poveži',
                    style: TextStyle(color: Colors.white),
                  ),
                onPressed: () async {
                  widget.flutterBlue.stopScan();
                  try {
                    await device.connect();
                    await device.requestMtu(123);
                  } catch (e) {
                    if (e.code != 'already_connected') {
                      throw e;
                    }
                  } finally {
                    _services = await device.discoverServices();
                  }
                  _connectedDevice = device;
                  //onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BleCharsPage(title: "ETURE zaklenilnica", srvs: _services, dev: _connectedDevice)),
                    );
                  //};
                },
              ),
    ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 10.0,
            ),
            SizedBox(height: 125.0,
              child: Image.asset(
                "assets/ETURE.jpg",
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 15.0),
            const Text(
              'Začni skenirat za BLE naprave:',
            ),
            SizedBox(height:15,
            ),
            ElevatedButton(
              onPressed: () {
                _scanForBleDevs();
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.lightBlue, // Background color
              ),
              child: const Text(
                'Skeniraj',
                style: TextStyle(fontSize: 17),
              ),
            ),
            SizedBox(height:20,
            ),
            SizedBox(
              height: 330.0,
              child: _buildListViewOfDevices(),
            ),
          ],
        ),
      ),
    );
  }
}

class BleCharsPage extends StatefulWidget {
  BleCharsPage({Key key, this.title, this.srvs, this.dev}) : super(key: key);

  final String title;
  final BluetoothDevice dev;
  List<BluetoothService> srvs;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = new List<BluetoothDevice>();
  final Map<Guid, List<int>> readValues = new Map<Guid, List<int>>();

  @override
  State<BleCharsPage> createState() => _BleCharsPageState();
}

class _BleCharsPageState extends State<BleCharsPage> {
  TextEditingController retValController = new TextEditingController();
  final _writeController = TextEditingController(text: "odpri\r");   // bike type

  ListView _buildConnectDeviceView() {
    List<Container> containers = new List<Container>();

    for (BluetoothService service in widget.srvs) {
      List<Widget> characteristicsWidget = new List<Widget>();

      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == '00002a05-0000-1000-8000-00805f9b34fb'){
          print('Exists');
          () async {
            characteristic.value.listen((value) async {
              ScaffoldMessenger.of(context).showSnackBar((SnackBar(content: Text("Notifications enabled"))));
              retValController.text = 'Success';
            });
            await characteristic.setNotifyValue(true);
          };
        }

        List<ButtonTheme> _buildReadWriteNotifyButton(
            BluetoothCharacteristic characteristic) {
          List<ButtonTheme> buttons = new List<ButtonTheme>();
          int msgInd = 1;
          int iCount = 1;
          String sRecData = "";

          if (characteristic.properties.write) {
            buttons.add(
              ButtonTheme(
                minWidth: 10,
                height: 20,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    child: Text('VNESI UKAZ', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("VNESI UKAZ"),
                              content: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: TextField(
                                          controller: _writeController,
                                        ),
                                      ),
                                    ],
                                  ),



                              actions: <Widget>[
                                TextButton(
                                  child: Text("Send"),
                                  onPressed: () {
                                    characteristic.write(
                                        utf8.encode(_writeController.value.text));
                                    Navigator.pop(context);
                                  },
                                ),
                                TextButton(
                                  child: Text("Cancel"),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            );
                          });
                    },
                  ),
                ),
              ),
            );
          }

          return buttons;
        }

        characteristicsWidget.add(
          Align(
            alignment: Alignment.center,
            child: Row(
                  children: <Widget>[
                    ..._buildReadWriteNotifyButton(characteristic),
                  ],
                ),

            ),
          );
      }
      containers.add(
        Container(
          child: ExpansionTile(
              children: characteristicsWidget,
              title: Text('/')),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(height:20,
            ),
            SizedBox(height: 180.0,
                width:200,
                child: Image.asset(
                  "assets/kolesarnica.PNG",
                ),
              ),
            SizedBox(height:20,
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.redAccent, // Background color
              ),
              child: const Text(
                'Nazaj',
                style: TextStyle(fontSize: 17),
              ),
            ),

            SizedBox(
              height: 290.0,

              child: _buildConnectDeviceView(),
            ),
          ],
        ),
      ),
    );
  }
}

