const Database = require('better-sqlite3');
const path = require('path');

// Initialize the database
const db = new Database(path.join(__dirname, 'database.sqlite'));

// Create the users table if it doesn't exist
db.exec(`
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT NOT NULL,
        password TEXT NOT NULL,
        account_cid TEXT NOT NULL, -- CID of the user's account file in Pinata
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
`);

// Create the products table if it doesn't exist
db.exec(`
    CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        cid TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id)
    );
`);

module.exports = db;