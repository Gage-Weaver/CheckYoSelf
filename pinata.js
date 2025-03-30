require('dotenv').config();
const axios = require('axios');

// Pinata API keys from .env
const PINATA_API_KEY = process.env.PINATA_API_KEY;
const PINATA_SECRET_API_KEY = process.env.PINATA_SECRET_API_KEY;
const PINATA_JWT = process.env.PINATA_JWT;

// Pinata base URL
const PINATA_BASE_URL = 'https://api.pinata.cloud';

/**
 * Check if a user already exists in the Pinata database
 * @param {string} username - The username to check
 * @returns {Promise<boolean>} - True if the user exists, false otherwise
 */
async function userExists(username) {
    try {
        // Search for the user's metadata on Pinata
        const response = await axios.get(
            `${PINATA_BASE_URL}/data/pinList?metadata[name]=User_${username}`,
            {
                headers: {
                    pinata_api_key: PINATA_API_KEY,
                    pinata_secret_api_key: PINATA_SECRET_API_KEY,
                },
            }
        );

        // If the response contains results, the user exists
        return response.data.count > 0;
    } catch (error) {
        console.error('Error checking user existence:', error.response?.data || error.message);
        throw error;
    }
}

/**
 * Create a user in the Pinata database
 * @param {string} username - The username of the user
 * @param {string} email - The email of the user
 * @param {string} password - The plaintext password of the user
 * @param {Array<string>} fileCIDs - Array of CIDs associated with the user
 * @returns {Promise<object>} - The response from Pinata
 */
async function createUser(username, email, password, fileCIDs = []) {
    try {
        const metadata = {
            username,
            email,
            password, // Store the plaintext password (not recommended for production)
            fileCIDs, // Array of CIDs associated with the user
            createdAt: new Date().toISOString(),
        };

        const response = await axios.post(
            `${PINATA_BASE_URL}/pinning/pinJSONToIPFS`,
            {
                pinataMetadata: {
                    name: `User_${username}`,
                    keyvalues: metadata, // Store user data in keyvalues
                },
                pinataContent: metadata, // Optional: Store the same data in the content
            },
            {
                headers: {
                    Authorization: `Bearer ${PINATA_JWT}`,
                },
            }
        );

        console.log('User created successfully:', response.data);
        return response.data;
    } catch (error) {
        console.error('Error creating user:', error.response?.data || error.message);
        throw error;
    }
}

/**
 * Transfer ownership of a product to another user
 * @param {string} productId - The ID of the product
 * @param {string} newOwner - The username of the new owner
 * @returns {Promise<object>} - The response from Pinata
 */
async function transferOwnership(productId, newOwner) {
    try {
        // Example metadata update
        const updatedMetadata = {
            productId,
            newOwner,
            transferredAt: new Date().toISOString(),
        };

        // Pin updated JSON to Pinata
        const response = await axios.post(
            `${PINATA_BASE_URL}/pinning/pinJSONToIPFS`,
            {
                pinataMetadata: {
                    name: `Transfer_${productId}`,
                },
                pinataContent: updatedMetadata,
            },
            {
                headers: {
                    pinata_api_key: PINATA_API_KEY,
                    pinata_secret_api_key: PINATA_SECRET_API_KEY,
                },
            }
        );

        console.log('Ownership transferred successfully:', response.data);
        return response.data;
    } catch (error) {
        console.error('Error transferring ownership:', error.response?.data || error.message);
        throw error;
    }
}

// Example usage
(async () => {
    // Create a user
    await createUser('john_doe', 'john@example.com', 'password123', ['cid1', 'cid2']);

    // Transfer ownership of a product
    await transferOwnership('product123', 'jane_doe');
})();

module.exports = {
    userExists,
    createUser,
    transferOwnership, // Export other functions if needed
};