const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
app.use(cors());

// Increase JSON limit to allow Base64 image uploads
app.use(express.json({ limit: '10mb' })); 

const JWT_SECRET = 'super_secret_jwt_key_change_this_in_production';

const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '', 
    database: 'digital_garden'
});

// JWT Middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) return res.status(401).json({ error: "Access Denied" });

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) return res.status(403).json({ error: "Invalid Token" });
        req.user = user;
        next();
    });
};

// --- AUTHENTICATION & PROFILE APIs ---
app.post('/api/auth/signup', async (req, res) => {
    const { name, email, password } = req.body;
    try {
        const hashedPassword = await bcrypt.hash(password, 10);
        await pool.query('INSERT INTO users (name, email, password) VALUES (?, ?, ?)', [name, email, hashedPassword]);
        res.status(201).json({ message: "User created" });
    } catch (err) {
        res.status(400).json({ error: "Email exists" });
    }
});

app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;
    try {
        const [users] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
        if (users.length === 0) return res.status(400).json({ error: "User not found" });

        const valid = await bcrypt.compare(password, users[0].password);
        if (!valid) return res.status(400).json({ error: "Invalid password" });

        const token = jwt.sign({ id: users[0].id }, JWT_SECRET);
        res.json({ token });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Profile endpoint includes total_spent
app.get('/api/auth/me', authenticateToken, async (req, res) => {
    try {
        const [users] = await pool.query('SELECT id, name, email, profile_pic, deaths, total_spent FROM users WHERE id = ?', [req.user.id]);
        res.json(users[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Upload Profile Picture (Base64)
app.put('/api/auth/profile_pic', authenticateToken, async (req, res) => {
    const { base64Image } = req.body;
    try {
        await pool.query('UPDATE users SET profile_pic = ? WHERE id = ?', [base64Image, req.user.id]);
        res.json({ message: 'Profile picture updated' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- STORE & PLANTS APIs ---
app.get('/api/store', async (req, res) => {
    try {
        const [rows] = await pool.query('SELECT * FROM store_plants');
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/plants', authenticateToken, async (req, res) => {
    try {
        const [rows] = await pool.query('SELECT * FROM owned_plants WHERE user_id = ? ORDER BY created_at DESC', [req.user.id]);
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Advanced Checkout: Adds plant details to owned_plants AND updates user total_spent
app.post('/api/checkout', authenticateToken, async (req, res) => {
    const { cart, totalAmount } = req.body; 
    try {
        // Update user spending
        await pool.query('UPDATE users SET total_spent = total_spent + ? WHERE id = ?', [totalAmount, req.user.id]);

        // Insert each plant into the garden with deep details
        for (let item of cart) {
            let img = JSON.parse(item.images)[0];
            await pool.query(
                `INSERT INTO owned_plants 
                (user_id, name, wateringFreq, sunlight, imageUrl, description, needs, fun_facts, care_tips) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [req.user.id, item.name, item.wateringFreq, item.sunlight, img, item.description, item.needs, item.fun_facts, item.care_tips]
            );
        }
        res.status(201).json({ message: 'Purchase complete' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.delete('/api/plants/:id/dead', authenticateToken, async (req, res) => {
    const { id } = req.params;
    try {
        await pool.query('DELETE FROM owned_plants WHERE id = ? AND user_id = ?', [id, req.user.id]);
        await pool.query('UPDATE users SET deaths = deaths + 1 WHERE id = ?', [req.user.id]);
        res.json({ message: 'Plant marked as dead' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.listen(3000, () => console.log('LeafLog V2 Server running on port 3000'));