import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game/provider/game-provider.dart';
import 'cactus.dart';
import 'cloud.dart';
import 'dino.dart';
import 'game-object.dart';
import 'ground.dart';
import 'constants.dart';

void main() {
  runApp(MyApp());
  SystemChrome.setEnabledSystemUIOverlays([]);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return MaterialApp(
      title: 'Flutter Dino game',
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  GameProvider gameProvider = GameProvider();

  Dino dino = Dino();
  double runVelocity = initialVelocity;
  double runDistance = 0;
  int highScore = 0;
  TextEditingController gravityController =
      TextEditingController(text: gravity.toString());
  TextEditingController accelerationController =
      TextEditingController(text: acceleration.toString());
  TextEditingController jumpVelocityController =
      TextEditingController(text: jumpVelocity.toString());
  TextEditingController runVelocityController =
      TextEditingController(text: initialVelocity.toString());
  TextEditingController dayNightOffestController =
      TextEditingController(text: dayNightOffest.toString());

  AnimationController worldController;
  Duration lastUpdateCall = Duration();

  List<Cactus> cacti = [Cactus(worldLocation: Offset(200, 0))];

  List<Ground> ground = [
    Ground(worldLocation: Offset(0, 0)),
    Ground(worldLocation: Offset(groundSprite.imageWidth / 10, 0))
  ];

  List<Cloud> clouds = [
    Cloud(worldLocation: Offset(100, 20)),
    Cloud(worldLocation: Offset(200, 10)),
    Cloud(worldLocation: Offset(350, -10)),
  ];

  @override
  void initState() {
    super.initState();
    worldController =
        AnimationController(vsync: this, duration: Duration(days: 99));
    worldController.addListener(_update);
    // worldController.forward();
    _die();
  }

  void _die() {
    setState(() {
      worldController.stop();
      dino.die();
    });
  }

  void _newGame() {
    setState(() {
      cacti = [Cactus(worldLocation: Offset(200, 0))];

      ground = [
        Ground(worldLocation: Offset(0, 0)),
        Ground(worldLocation: Offset(groundSprite.imageWidth / 10, 0))
      ];

      clouds = [
        Cloud(worldLocation: Offset(100, 20)),
        Cloud(worldLocation: Offset(200, 10)),
        Cloud(worldLocation: Offset(350, -10)),
      ];
      highScore = max(highScore, runDistance.toInt());
      runDistance = 0;
      runVelocity = initialVelocity;
      dino.state = DinoState.running;
      worldController.reset();
      worldController.forward();
    });
  }

  _update() {
    double elapsedTimeSeconds;
    dino.update(lastUpdateCall, worldController.lastElapsedDuration);
    try {
      elapsedTimeSeconds =
          (worldController.lastElapsedDuration - lastUpdateCall)
                  .inMilliseconds /
              1000;
    } catch (_) {
      elapsedTimeSeconds = 0;
    }

    runDistance += runVelocity * elapsedTimeSeconds;
    runVelocity += acceleration * elapsedTimeSeconds;

    Size screenSize = MediaQuery.of(context).size;

    Rect dinoRect = dino.getRect(screenSize, runDistance);
    for (Cactus cactus in cacti) {
      Rect obstacleRect = cactus.getRect(screenSize, runDistance);
      if (dinoRect.overlaps(obstacleRect.deflate(20))) {
        _die();
        gameProvider.showPrize(context, runDistance.toInt());
      }

      if (obstacleRect.right < 0) {
        setState(() {
          cacti.remove(cactus);
          cacti.add(Cactus(
              worldLocation:
                  Offset(runDistance + Random().nextInt(100) + 50, 0)));
        });
      }
    }

    for (Ground groundlet in ground) {
      if (groundlet.getRect(screenSize, runDistance).right < 0) {
        setState(() {
          ground.remove(groundlet);
          ground.add(Ground(
              worldLocation: Offset(
                  ground.last.worldLocation.dx + groundSprite.imageWidth / 10,
                  0)));
        });
      }
    }

    for (Cloud cloud in clouds) {
      if (cloud.getRect(screenSize, runDistance).right < 0) {
        setState(() {
          clouds.remove(cloud);
          clouds.add(Cloud(
              worldLocation: Offset(
                  clouds.last.worldLocation.dx + Random().nextInt(100) + 50,
                  Random().nextInt(40) - 20.0)));
        });
      }
    }

    lastUpdateCall = worldController.lastElapsedDuration;
  }

  @override
  void dispose() {
    gravityController.dispose();
    accelerationController.dispose();
    jumpVelocityController.dispose();
    runVelocityController.dispose();
    dayNightOffestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    List<Widget> children = [];

    for (GameObject object in [...clouds, ...ground, ...cacti, dino]) {
      children.add(
        AnimatedBuilder(
          animation: worldController,
          builder: (context, _) {
            Rect objectRect = object.getRect(screenSize, runDistance);
            return Positioned(
              left: objectRect.left,
              top: objectRect.top,
              width: objectRect.width,
              height: objectRect.height,
              child: object.render(),
            );
          },
        ),
      );
    }

    return Scaffold(
      body: AnimatedContainer(
        duration: Duration(milliseconds: 5000),
        color: (runDistance ~/ dayNightOffest) % 2 == 0
            ? Colors.white
            : Colors.black,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (dino.state != DinoState.dead) {
              dino.jump();
            }
            if (dino.state == DinoState.dead) {
              _newGame();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...children,
              AnimatedBuilder(
                animation: worldController,
                builder: (context, _) {
                  return Positioned(
                    left: screenSize.width / 2 - 30,
                    top: 100,
                    child: Text(
                      'Score: ' + runDistance.toInt().toString(),
                      style: TextStyle(
                        color: (runDistance ~/ dayNightOffest) % 2 == 0
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: worldController,
                builder: (context, _) {
                  return Positioned(
                    left: screenSize.width / 2 - 50,
                    top: 120,
                    child: Text(
                      'High Score: ' + highScore.toString(),
                      style: TextStyle(
                        color: (runDistance ~/ dayNightOffest) % 2 == 0
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                right: 20,
                top: 20,
                child: IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    _die();
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Change Physics"),
                          actions: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                height: 25,
                                width: 280,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Gravity:"),
                                    SizedBox(
                                      child: TextField(
                                        controller: gravityController,
                                        key: UniqueKey(),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                        ),
                                      ),
                                      height: 25,
                                      width: 75,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                height: 25,
                                width: 280,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Acceleration:"),
                                    SizedBox(
                                      child: TextField(
                                        controller: accelerationController,
                                        key: UniqueKey(),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                        ),
                                      ),
                                      height: 25,
                                      width: 75,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                height: 25,
                                width: 280,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Initial Velocity:"),
                                    SizedBox(
                                      child: TextField(
                                        controller: runVelocityController,
                                        key: UniqueKey(),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                        ),
                                      ),
                                      height: 25,
                                      width: 75,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                height: 25,
                                width: 280,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Jump Velocity:"),
                                    SizedBox(
                                      child: TextField(
                                        controller: jumpVelocityController,
                                        key: UniqueKey(),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                        ),
                                      ),
                                      height: 25,
                                      width: 75,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                height: 25,
                                width: 280,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Day-Night Offset:"),
                                    SizedBox(
                                      child: TextField(
                                        controller: dayNightOffestController,
                                        key: UniqueKey(),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                        ),
                                      ),
                                      height: 25,
                                      width: 75,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            FlatButton(
                              onPressed: () {
                                gravity = int.parse(gravityController.text);
                                acceleration =
                                    double.parse(accelerationController.text);
                                initialVelocity =
                                    double.parse(runVelocityController.text);
                                jumpVelocity =
                                    double.parse(jumpVelocityController.text);
                                dayNightOffest =
                                    int.parse(dayNightOffestController.text);
                                Navigator.of(context).pop();
                              },
                              child: Text("Done"),
                              textColor: Colors.grey,
                            )
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 10,
                child: FlatButton(
                  onPressed: () {
                    _die();
                  },
                  child: Text("Made by Mohit rao"),
                  textColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
