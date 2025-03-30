const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');
const axios = require('axios'); // Import axios for HTTP requests
const db = require('./database'); // Import the SQLite database
require('dotenv').config();

const PINATA_BASE_URL = 'https://api.pinata.cloud'; // Base URL for Pinata API
const PINATA_JWT = process.env.PINATA_JWT; // Pinata JWT from environment variables

const app = express();
app.use(bodyParser.json()); // Middleware to parse JSON requests

// Serve static files from the "public" directory
app.use(express.static(path.join(__dirname, 'public')));

// Create a new user
app.post('/api/createUser', async (req, res) => {
    const { username, email, password } = req.body;

    try {
        // Step 1: Create an empty account file in Pinata
        const accountFile = {
            username,
            products: [], // Empty array for product CIDs
        };

        const pinataResponse = await axios.post(
            `${PINATA_BASE_URL}/pinning/pinJSONToIPFS`,
            {
                pinataMetadata: {
                    name: `Account_${username}`,
                },
                pinataContent: accountFile,
            },
            {
                headers: {
                    Authorization: `Bearer ${PINATA_JWT}`,
                },
            }
        );

        const accountCID = pinataResponse.data.IpfsHash;

        // Step 2: Store the user in SQLite
        const stmt = db.prepare(
            'INSERT INTO users (username, email, password, account_cid) VALUES (?, ?, ?, ?)'
        );
        stmt.run(username, email, password, accountCID);

        res.json({ success: true, message: 'User created successfully', accountCID });
    } catch (error) {
        console.error('Error creating user:', error.message);
        if (error.message.includes('UNIQUE constraint failed')) {
            res.status(400).json({ success: false, message: 'Username already exists' });
        } else {
            res.status(500).json({ success: false, message: 'Internal server error' });
        }
    }
});

// Login a user
app.post('/api/login', (req, res) => {
    const { username, password } = req.body;

    try {
        const stmt = db.prepare('SELECT id, password, account_cid FROM users WHERE username = ?');
        const user = stmt.get(username);

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        if (user.password !== password) {
            return res.status(401).json({ success: false, message: 'Invalid password' });
        }

        res.json({ success: true, userId: user.id, accountCID: user.account_cid });
    } catch (error) {
        console.error('Error during login:', error.message);
        res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// Get inventory items
app.get('/api/getInventory', async (req, res) => {
    const { userId } = req.query;

    try {
        // Step 1: Get the user's account CID from SQLite
        const stmt = db.prepare('SELECT account_cid FROM users WHERE id = ?');
        const user = stmt.get(userId);

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const accountCID = user.account_cid;

        // Step 2: Fetch the account file from Pinata
        const accountResponse = await axios.get(
            `https://gateway.pinata.cloud/ipfs/${accountCID}`
        );

        const accountFile = accountResponse.data;
        const productCIDs = accountFile.products || [];

        // Step 3: Fetch product details for each CID
        const products = await Promise.all(
            productCIDs.map(async (cid) => {
                const productResponse = await axios.get(
                    `https://gateway.pinata.cloud/ipfs/${cid}`
                );
                return productResponse.data;
            })
        );

        res.json(products);
    } catch (error) {
        console.error('Error fetching inventory:', error.message);
        res.status(500).json({ error: 'Failed to fetch inventory' });
    }
});

// Create a new product
app.post('/api/createProduct', (req, res) => {
    const { userId, cid, name, description } = req.body;

    try {
        const stmt = db.prepare('INSERT INTO products (user_id, cid, name, description) VALUES (?, ?, ?, ?)');
        stmt.run(userId, cid, name, description);

        res.json({ success: true, message: 'Product created successfully' });
    } catch (error) {
        console.error('Error creating product:', error.message);
        res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// Add a product to user's account
app.post('/api/addProduct', async (req, res) => {
    const { userId, productData } = req.body;

    try {
        // Step 1: Pin the product file to Pinata
        const pinataResponse = await axios.post(
            `${PINATA_BASE_URL}/pinning/pinJSONToIPFS`,
            {
                pinataMetadata: {
                    name: `Product_${productData.name}`,
                },
                pinataContent: productData,
            },
            {
                headers: {
                    Authorization: `Bearer ${PINATA_JWT}`,
                },
            }
        );

        const productCID = pinataResponse.data.IpfsHash;

        // Step 2: Get the user's account CID from SQLite
        const stmt = db.prepare('SELECT account_cid FROM users WHERE id = ?');
        const user = stmt.get(userId);

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const accountCID = user.account_cid;

        // Step 3: Fetch the account file from Pinata
        const accountResponse = await axios.get(
            `https://gateway.pinata.cloud/ipfs/${accountCID}`
        );

        const accountFile = accountResponse.data;

        // Step 4: Add the product CID to the account file
        accountFile.products.push(productCID);

        // Step 5: Update the account file in Pinata
        await axios.post(
            `${PINATA_BASE_URL}/pinning/pinJSONToIPFS`,
            {
                pinataMetadata: {
                    name: `Account_${user.username}`,
                },
                pinataContent: accountFile,
            },
            {
                headers: {
                    Authorization: `Bearer ${PINATA_JWT}`,
                },
            }
        );

        res.json({ success: true, message: 'Product added successfully', productCID });
    } catch (error) {
        console.error('Error adding product:', error.message);
        res.status(500).json({ error: 'Failed to add product' });
    }
});

// Fallback to serve index.html for unknown routes (only for Single Page Applications)
app.get('*', (req, res) => {
    const requestedPath = req.path;

    // If the requested path is not an API route or static file, serve index.html
    if (!requestedPath.startsWith('/api') && !requestedPath.includes('.')) {
        res.sendFile(path.join(__dirname, 'public', 'index.html'));
    } else {
        res.status(404).send('Not Found');
    }
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});