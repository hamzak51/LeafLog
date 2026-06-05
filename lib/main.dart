import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() => runApp(DigitalGardenApp());

const String baseUrl = "http://localhost:3000/api";

// Modern Color Palette
const Color primaryGreen = Color(0xFF2D6A4F);
const Color bgLight = Color(0xFFF4F6F5);
const Color textDark = Color(0xFF1B4332);

List<StorePlant> cart = [];

class DigitalGardenApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryGreen,
        scaffoldBackgroundColor: bgLight,
        appBarTheme: AppBarTheme(backgroundColor: bgLight, elevation: 0, iconTheme: IconThemeData(color: textDark), titleTextStyle: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.bold)),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ),
      home: LoginScreen(),
    );
  }
}

// --- Models ---
class OwnedPlant {
  final int id;
  final String name;
  String status;
  String lastWatered;
  final String wateringFreq;
  final String sunlight;
  final String? imageUrl;
  final String description;
  final String needs;
  final String funFacts;
  final String careTips;
  final String createdAt;

  OwnedPlant({required this.id, required this.name, this.status = "Healthy", this.lastWatered = "Just now", required this.wateringFreq, required this.sunlight, this.imageUrl, required this.description, required this.needs, required this.funFacts, required this.careTips, required this.createdAt});

  factory OwnedPlant.fromJson(Map<String, dynamic> json) {
    return OwnedPlant(
        id: json['id'], name: json['name'], status: json['status'], lastWatered: json['lastWatered'],
        wateringFreq: json['wateringFreq'], sunlight: json['sunlight'], imageUrl: json['imageUrl'],
        description: json['description'] ?? "No description.", needs: json['needs'] ?? "Water and light.",
        funFacts: json['fun_facts'] ?? "Plants are awesome.", careTips: json['care_tips'] ?? "Don't overwater.",
        createdAt: json['created_at']
    );
  }

  int get daysAlive {
    final birth = DateTime.parse(createdAt);
    return DateTime.now().difference(birth).inDays;
  }
}

class StorePlant {
  final int id;
  final String name;
  final String description;
  final String needs;
  final String funFacts;
  final String careTips;
  final double price;
  final String wateringFreq;
  final String sunlight;
  final List<String> images;

  StorePlant({required this.id, required this.name, required this.description, required this.needs, required this.funFacts, required this.careTips, required this.price, required this.wateringFreq, required this.sunlight, required this.images});

  factory StorePlant.fromJson(Map<String, dynamic> json) {
    var imgs = jsonDecode(json['images']) as List;
    return StorePlant(
        id: json['id'], name: json['name'], description: json['description'], needs: json['needs'], funFacts: json['fun_facts'], careTips: json['care_tips'],
        price: double.parse(json['price'].toString()), wateringFreq: json['wateringFreq'],
        sunlight: json['sunlight'], images: imgs.map((e) => e.toString()).toList()
    );
  }
}

// --- API Service ---
class ApiService {
  static Future<Map<String, String>> _headers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {"Content-Type": "application/json", "Authorization": "Bearer ${prefs.getString('jwt')}"};
  }

  static Future<bool> login(String email, String password) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/login'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"email": email, "password": password}));
    if (res.statusCode == 200) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', jsonDecode(res.body)['token']);
      return true;
    }
    return false;
  }

  static Future<bool> signup(String name, String email, String password) async {
    final res = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name, "email": email, "password": password})
    );
    return res.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getProfile() async => jsonDecode((await http.get(Uri.parse('$baseUrl/auth/me'), headers: await _headers())).body);

  static Future<void> uploadProfilePic(String base64Img) async {
    await http.put(Uri.parse('$baseUrl/auth/profile_pic'), headers: await _headers(), body: jsonEncode({"base64Image": base64Img}));
  }

  static Future<List<OwnedPlant>> fetchOwnedPlants() async {
    final res = await http.get(Uri.parse('$baseUrl/plants'), headers: await _headers());
    return List<OwnedPlant>.from(jsonDecode(res.body).map((m) => OwnedPlant.fromJson(m)));
  }

  static Future<void> markDead(int id) async => await http.delete(Uri.parse('$baseUrl/plants/$id/dead'), headers: await _headers());

  static Future<void> completeCheckout(double total) async {
    List<Map<String, dynamic>> cartData = cart.map((p) => {"name": p.name, "wateringFreq": p.wateringFreq, "sunlight": p.sunlight, "images": jsonEncode(p.images), "description": p.description, "needs": p.needs, "fun_facts": p.funFacts, "care_tips": p.careTips}).toList();
    await http.post(Uri.parse('$baseUrl/checkout'), headers: await _headers(), body: jsonEncode({"cart": cartData, "totalAmount": total}));
  }
}

// --- Helper Widget: Safe Image ---
Widget safeImage(String? url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  if (url == null || url.isEmpty) return Icon(Icons.eco, size: 50, color: Colors.grey);
  if (url.startsWith('data:image')) {
    return Image.memory(base64Decode(url.split(',')[1]), width: width, height: height, fit: fit);
  }
  return Image.network(url, width: width, height: height, fit: fit, errorBuilder: (ctx, err, stack) => Icon(Icons.image_not_supported, color: Colors.grey));
}

// --- Login Screen ---
class LoginScreen extends StatefulWidget { @override _LoginScreenState createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(), _password = TextEditingController();

  void _login() async {
    if (await ApiService.login(_email.text, _password.text)) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Dashboard()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed"), backgroundColor: Colors.red));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(body: Center(child: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(children: [
      Icon(Icons.spa, size: 80, color: primaryGreen), SizedBox(height: 20),
      Text("LeafLog", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textDark)), SizedBox(height: 40),

      TextField(controller: _email, decoration: InputDecoration(labelText: "Email", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), SizedBox(height: 16),
      TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: "Password", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), SizedBox(height: 24),

      ElevatedButton(onPressed: _login, child: Text("Sign In"), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55))),
      SizedBox(height: 16),

      // THIS IS THE NEW BUTTON YOU NEED
      TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SignupScreen())),
          child: Text("Don't have an account? Sign Up", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w600))
      )
    ]))));
  }
}

// --- Signup Screen ---
class SignupScreen extends StatefulWidget {
  @override _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController(), _email = TextEditingController(), _password = TextEditingController();
  bool _isLoading = false;

  void _signup() async {
    if (_name.text.isEmpty || _email.text.isEmpty || _password.text.isEmpty) return;
    setState(() => _isLoading = true);

    bool success = await ApiService.signup(_name.text, _email.text, _password.text);
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Account created! Please sign in."), backgroundColor: primaryGreen));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Email already exists or error occurred."), backgroundColor: Colors.red));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: textDark)),
      body: Center(child: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(children: [
        Icon(Icons.person_add_alt_1, size: 80, color: primaryGreen), SizedBox(height: 20),
        Text("Join LeafLog", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textDark)), SizedBox(height: 40),

        TextField(controller: _name, decoration: InputDecoration(labelText: "Full Name", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), SizedBox(height: 16),
        TextField(controller: _email, decoration: InputDecoration(labelText: "Email", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), SizedBox(height: 16),
        TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: "Password", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), SizedBox(height: 24),

        _isLoading ? CircularProgressIndicator(color: primaryGreen) : ElevatedButton(onPressed: _signup, child: Text("Create Account"), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55))),
      ]))),
    );
  }
}

// --- Dashboard ---
class Dashboard extends StatefulWidget { @override _DashboardState createState() => _DashboardState(); }
class _DashboardState extends State<Dashboard> {
  List<OwnedPlant> myPlants = []; bool isLoading = true;
  @override void initState() { super.initState(); _load(); }
  void _load() async { setState(() => isLoading = true); final p = await ApiService.fetchOwnedPlants(); setState(() { myPlants = p; isLoading = false; }); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Sanctuary"), actions: [
        IconButton(icon: Icon(Icons.person_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())).then((_) => _load())),
        IconButton(icon: Icon(Icons.storefront), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen())).then((_) => _load())),
      ]),
      body: isLoading ? Center(child: CircularProgressIndicator(color: primaryGreen)) : GridView.builder(
        padding: EdgeInsets.all(16), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
        itemCount: myPlants.length, itemBuilder: (context, index) {
        final p = myPlants[index];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlantDetail(plant: p))).then((_) => _load()),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(fit: StackFit.expand, children: [
              safeImage(p.imageUrl),
              Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.7), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter))),
              Positioned(bottom: 12, left: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Alive: ${p.daysAlive} Days", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]))
            ]),
          ),
        );
      },
      ),
    );
  }
}

// --- Profile Screen ---
class ProfileScreen extends StatefulWidget { @override _ProfileScreenState createState() => _ProfileScreenState(); }
class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? user; int plantCount = 0;
  @override void initState() { super.initState(); _load(); }
  void _load() async { final u = await ApiService.getProfile(); final p = await ApiService.fetchOwnedPlants(); setState(() { user = u; plantCount = p.length; }); }

  void _uploadPic() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600);
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      String base64String = "data:image/jpeg;base64," + base64Encode(bytes);
      await ApiService.uploadProfilePic(base64String);
      _load();
    }
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance(); prefs.remove('jwt');
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (route) => false);
  }

  @override Widget build(BuildContext context) {
    if (user == null) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(onTap: _uploadPic, child: CircleAvatar(radius: 60, backgroundImage: user!['profile_pic'] != null && user!['profile_pic'].startsWith('data') ? MemoryImage(base64Decode(user!['profile_pic'].split(',')[1])) : null, child: user!['profile_pic'] == null ? Icon(Icons.camera_alt, size: 40) : null)),
        SizedBox(height: 20),
        Text(user!['name'], style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textDark)),
        Text(user!['email'], style: TextStyle(fontSize: 16, color: Colors.grey[600])), SizedBox(height: 40),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _stat("Plants", plantCount.toString()), _stat("Lost", user!['deaths'].toString()), _stat("Spent", "PKR ${user!['total_spent']}"),
        ]),
        Spacer(),
        Padding(padding: EdgeInsets.all(24), child: ElevatedButton.icon(onPressed: _logout, icon: Icon(Icons.logout), label: Text("Logout"), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: Size(double.infinity, 50)))),
      ])),
    );
  }
  Widget _stat(String label, String val) => Column(children: [Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)), Text(label, style: TextStyle(color: Colors.grey[700]))]);
}

// --- Owned Plant Detail ---
class PlantDetail extends StatelessWidget {
  final OwnedPlant plant;
  PlantDetail({required this.plant});

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(expandedHeight: 350, pinned: true, flexibleSpace: FlexibleSpaceBar(title: Text(plant.name, style: TextStyle(color: Colors.white, textBaseline: TextBaseline.alphabetic, shadows: [Shadow(color: Colors.black, blurRadius: 10)])), background: safeImage(plant.imageUrl))),
        SliverPadding(padding: EdgeInsets.all(20), sliver: SliverList(delegate: SliverChildListDelegate([
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _badge(Icons.calendar_today, "${plant.daysAlive} Days Alive"), _badge(Icons.water_drop, plant.status),
          ]), SizedBox(height: 24),
          _section("Description", plant.description), _section("Optimal Needs", plant.needs),
          _section("Care Tips", plant.careTips), _section("Fun Fact", plant.funFacts),
          SizedBox(height: 30),
          ElevatedButton.icon(icon: Icon(Icons.sentiment_very_dissatisfied), label: Text("Mark as Dead"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red[300], minimumSize: Size(double.infinity, 50)), onPressed: () async { await ApiService.markDead(plant.id); Navigator.pop(context); })
        ])))
      ]),
    );
  }
  Widget _badge(IconData icon, String text) => Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: Row(children: [Icon(icon, size: 16, color: primaryGreen), SizedBox(width: 6), Text(text, style: TextStyle(fontWeight: FontWeight.bold))]));
  Widget _section(String title, String content) => Padding(padding: EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)), SizedBox(height: 8), Text(content, style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5))]));
}

// --- Store ---
class StoreScreen extends StatefulWidget { @override _StoreScreenState createState() => _StoreScreenState(); }
class _StoreScreenState extends State<StoreScreen> {
  List<StorePlant> storePlants = [];
  @override void initState() { super.initState(); _load(); }
  void _load() async { final res = await http.get(Uri.parse('$baseUrl/store')); setState(() => storePlants = List<StorePlant>.from(jsonDecode(res.body).map((m) => StorePlant.fromJson(m)))); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Boutique"), actions: [IconButton(icon: Icon(Icons.shopping_bag_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen())))]),
      body: ListView.separated(
        padding: EdgeInsets.all(16), itemCount: storePlants.length, separatorBuilder: (_,__) => SizedBox(height: 16),
        itemBuilder: (ctx, i) {
          final p = storePlants[i];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(plant: p))),
            child: Container(
              height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0,4))]),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.horizontal(left: Radius.circular(16)), child: safeImage(p.images[0], width: 120, height: 120)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(p.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)), SizedBox(height: 8),
                  Text("PKR ${p.price.toStringAsFixed(0)}", style: TextStyle(fontSize: 16, color: primaryGreen, fontWeight: FontWeight.w600)),
                ]))
              ]),
            ),
          );
        },
      ),
    );
  }
}

class StoreDetailScreen extends StatefulWidget { final StorePlant plant; StoreDetailScreen({required this.plant}); @override _StoreDetailScreenState createState() => _StoreDetailScreenState(); }
class _StoreDetailScreenState extends State<StoreDetailScreen> {
  int quantity = 1;
  @override Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(expandedHeight: 400, pinned: true, flexibleSpace: FlexibleSpaceBar(background: safeImage(widget.plant.images[0]))),
        SliverPadding(padding: EdgeInsets.all(20), sliver: SliverList(delegate: SliverChildListDelegate([
          Text(widget.plant.name, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark)), SizedBox(height: 10),
          Text("PKR ${widget.plant.price.toStringAsFixed(0)}", style: TextStyle(fontSize: 22, color: primaryGreen, fontWeight: FontWeight.w600)), SizedBox(height: 20),
          Text(widget.plant.description, style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5)), SizedBox(height: 30),
          Row(children: [
            Text("Quantity:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Spacer(),
            IconButton(icon: Icon(Icons.remove_circle_outline), onPressed: () => setState(() { if(quantity > 1) quantity--; })),
            Text("$quantity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(icon: Icon(Icons.add_circle_outline), onPressed: () => setState(() => quantity++)),
          ]), SizedBox(height: 30),
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55)),
              child: Text("Add ${quantity} to Cart - PKR ${(widget.plant.price * quantity).toStringAsFixed(0)}"),
              onPressed: () { for(int i=0; i<quantity; i++) cart.add(widget.plant); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added to cart!"), backgroundColor: primaryGreen)); }
          )
        ])))
      ]),
    );
  }
}

// --- Checkout ---
class CheckoutScreen extends StatelessWidget {
  @override Widget build(BuildContext context) {
    double total = cart.fold(0, (sum, item) => sum + item.price);
    return Scaffold(
      appBar: AppBar(title: Text("Cart")),
      body: Padding(padding: EdgeInsets.all(20), child: Column(children: [
        Expanded(child: ListView.builder(itemCount: cart.length, itemBuilder: (ctx, i) => ListTile(leading: Icon(Icons.eco, color: primaryGreen), title: Text(cart[i].name), trailing: Text("PKR ${cart[i].price.toStringAsFixed(0)}")))),
        Divider(thickness: 2), SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Total:", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text("PKR ${total.toStringAsFixed(0)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen))]),
        SizedBox(height: 30),
        ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 60)), child: Text("Complete Purchase", style: TextStyle(fontSize: 18)),
            onPressed: () async {
              if(cart.isEmpty) return;
              await ApiService.completeCheckout(total); cart.clear();
              Navigator.popUntil(context, (route) => route.isFirst);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Order Successful!"), backgroundColor: primaryGreen));
            }
        )
      ])),
    );
  }
}