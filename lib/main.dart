import 'package:flutter/material.dart';

void main() => runApp(DigitalGardenApp());

// Global variables for our "No-Backend" session
List<Plant> myPlants = [
  Plant(name: "Wintercress", status: "Green", lastWatered: "2 hrs ago", wateringFreq: "Every 2 days", sunlight: "Partial"),
  Plant(name: "Snake Plant", status: "Yellow", lastWatered: "5 days ago", wateringFreq: "Every 14 days", sunlight: "Low"),
];
int plantDeaths = 0;

class DigitalGardenApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, scaffoldBackgroundColor: Color(0xFFF9F9F9)),
      home: LoginScreen(),
    );
  }
}

class Plant {
  String name;
  String status;
  String lastWatered;
  String wateringFreq;
  String sunlight;

  Plant({required this.name, required this.status, required this.lastWatered, required this.wateringFreq, required this.sunlight});
}

// --- Login Screen ---
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() {
    if (_emailController.text == "hamza@yahoo.com" && _passwordController.text == "admin") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Dashboard()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid Credentials"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 80, color: Colors.green),
            Text("LeafLog", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green[800])),
            SizedBox(height: 40),
            TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            SizedBox(height: 16),
            TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder())),
            SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _handleLogin, child: Text("Login"))),
          ],
        ),
      ),
    );
  }
}

// --- Dashboard ---
class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _remindController = TextEditingController();

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("LeafLog"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.green[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCard("Alive", "${myPlants.length}", Colors.green),
                _statCard("Deaths", "$plantDeaths", Colors.red),
                _statCard("Age", "1 Day", Colors.brown),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.9),
              itemCount: myPlants.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (context) => PlantDetail(plantIndex: index),
                    ));
                    _refresh(); // Refresh dashboard when coming back
                  },
                  child: Card(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(backgroundColor: myPlants[index].status == "Green" ? Colors.green : Colors.yellow, radius: 6),
                        Text(myPlants[index].name, style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Watered: ${myPlants[index].lastWatered}", style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: _nameController, decoration: InputDecoration(labelText: "Plant Name")),
                  TextField(controller: _remindController, decoration: InputDecoration(labelText: "Schedule")),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        myPlants.add(Plant(name: _nameController.text, status: "Green", lastWatered: "Just now", wateringFreq: _remindController.text, sunlight: "Partial"));
                      });
                      Navigator.pop(context);
                    },
                    child: Text("Save"),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Column(children: [Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)), Text(label)]);
  }
}

// --- Plant Detail (Now with Action Buttons) ---
class PlantDetail extends StatefulWidget {
  final int plantIndex;
  PlantDetail({required this.plantIndex});

  @override
  _PlantDetailState createState() => _PlantDetailState();
}

class _PlantDetailState extends State<PlantDetail> {

  // Helper function to show the "flash" notification
  void _showNotification(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating, // Makes it look like a floating flash
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plantIndex >= myPlants.length) return Scaffold();

    final plant = myPlants[widget.plantIndex];

    return Scaffold(
      appBar: AppBar(title: Text(plant.name)),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                height: 180, width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(15)
                ),
                child: Icon(Icons.eco, size: 80, color: Colors.green[900]),
              ),
              SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. WATER ACTION
                  _actionButton("Water", Icons.water_drop, Colors.blue, () {
                    setState(() {
                      plant.lastWatered = "Just now";
                      plant.status = "Green";
                    });
                    _showNotification("${plant.name} is now hydrated! 💧", Colors.blue);
                  }),

                  // 2. DEATH ACTION
                  _actionButton("Death", Icons.sentiment_very_dissatisfied, Colors.orange, () {
                    String name = plant.name;
                    setState(() {
                      plantDeaths++;
                      myPlants.removeAt(widget.plantIndex);
                    });
                    // Close screen and show notification on the dashboard
                    Navigator.pop(context);
                    _showNotification("$name has been moved to the graveyard. 🍂", Colors.orange[800]!);
                  }),

                  // 3. DELETE ACTION
                  _actionButton("Delete", Icons.delete, Colors.red, () {
                    String name = plant.name;
                    setState(() {
                      myPlants.removeAt(widget.plantIndex);
                    });
                    Navigator.pop(context);
                    _showNotification("$name removed from garden. 🗑️", Colors.red);
                  }),
                ],
              ),

              SizedBox(height: 20),
              _detailTile("Watering Frequency", plant.wateringFreq),
              _detailTile("Sunlight Needs", plant.sunlight),
              _detailTile("Last Watered", plant.lastWatered),
              _detailTile("Health Status", plant.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback tap) {
    return Column(
      children: [
        IconButton(icon: Icon(icon, color: color, size: 30), onPressed: tap),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _detailTile(String label, String value) {
    return ListTile(
        title: Text(label),
        trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900]))
    );
  }
}