import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart';

void main() {
  runApp(VirtualAquariumApp());
}

class VirtualAquariumApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Aquarium',
      theme: ThemeData.dark(),
      home: AquariumScreen(),
    );
  }
}

class Fish {
  final Color color;
  final double speed;
  Offset position;

  Fish({required this.color, required this.speed})
      : position = Offset(
      Random().nextDouble() * 280, // Max x value within container (300 - fish size)
      Random().nextDouble() * 280); // Max y value within container (300 - fish size)
}

class AquariumScreen extends StatefulWidget {
  @override
  _AquariumScreenState createState() => _AquariumScreenState();
}

class _AquariumScreenState extends State<AquariumScreen> with TickerProviderStateMixin {
  List<Fish> fishList = [];
  Color selectedColor = Colors.blue;
  double selectedSpeed = 1.0;
  late AnimationController _controller;
  Random random = Random();
  late Timer _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: Duration(seconds: 10))
      ..repeat();

    _controller.addListener(_updateFishPositions);

    // Optional: Slower movement updates using a Timer
    _timer = Timer.periodic(Duration(milliseconds: 50000), (Timer t) {
      _updateFishPositions();
    });

    _loadSettings();
  }

  void _updateFishPositions() {
    setState(() {
      for (Fish fish in fishList) {
        Offset delta = Offset(
          (random.nextDouble() - 0.5) * fish.speed * 5, // Reduced movement distance
          (random.nextDouble() - 0.5) * fish.speed * 5,
        );
        fish.position += delta;

        // Handle fish bouncing off the walls
        if (fish.position.dx < 0 || fish.position.dx > 280) {
          fish.position = Offset(fish.position.dx.clamp(0, 280), fish.position.dy);
        }
        if (fish.position.dy < 0 || fish.position.dy > 280) {
          fish.position = Offset(fish.position.dx, fish.position.dy.clamp(0, 280));
        }
      }
    });
  }

  void _addFish() {
    if (fishList.length < 10) {
      setState(() {
        fishList.add(Fish(color: selectedColor, speed: selectedSpeed));
      });
    }
  }

  Future<void> _saveSettings() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'aquarium.db');
    final database = await openDatabase(path, version: 1,
        onCreate: (db, version) {
          return db.execute(
            'CREATE TABLE settings(id INTEGER PRIMARY KEY, fish_count INTEGER, speed REAL, color INTEGER)',
          );
        });

    await database.insert(
      'settings',
      {
        'fish_count': fishList.length,
        'speed': selectedSpeed,
        'color': selectedColor.value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _loadSettings() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'aquarium.db');
    final database = await openDatabase(path);

    final List<Map<String, dynamic>> settings = await database.query('settings');

    if (settings.isNotEmpty) {
      final savedData = settings.first;
      setState(() {
        int fishCount = savedData['fish_count'];
        selectedSpeed = savedData['speed'];
        selectedColor = Color(savedData['color']);
        fishList = List.generate(fishCount, (index) => Fish(color: selectedColor, speed: selectedSpeed));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel(); // Stop the timer when the screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Virtual Aquarium')),
      body: Column(
        children: [
          Container(
            height: 300,
            width: 300,
            color: Colors.lightBlueAccent,
            child: Stack(
              children: fishList.map((fish) {
                return Positioned(
                  left: fish.position.dx,
                  top: fish.position.dy,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 500), // Smooth animation
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: fish.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 20),
          Text('Fish Settings:'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Speed:'),
              Slider(
                value: selectedSpeed,
                min: 0.5,
                max: 5.0,
                onChanged: (value) {
                  setState(() {
                    selectedSpeed = value;
                  });
                },
              ),
              DropdownButton<Color>(
                value: selectedColor,
                items: [
                  DropdownMenuItem(value: Colors.blue, child: Text('Blue')),
                  DropdownMenuItem(value: Colors.red, child: Text('Red')),
                  DropdownMenuItem(value: Colors.green, child: Text('Green')),
                  DropdownMenuItem(value: Colors.yellow, child: Text('Yellow')),
                ],
                onChanged: (Color? newColor) {
                  setState(() {
                    selectedColor = newColor!;
                  });
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _addFish,
                child: Text('Add Fish'),
              ),
              SizedBox(width: 20),
              ElevatedButton(
                onPressed: _saveSettings,
                child: Text('Save Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
