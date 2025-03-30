import os
import sys
import tempfile
import uuid  # <-- New import for generating unique IDs
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from werkzeug.utils import secure_filename
from usdz_converter import usdz_to_glb

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes and origins

# Configure upload folder (temporary directory)
UPLOAD_FOLDER = tempfile.mkdtemp()
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB max upload

@app.route('/api/convert', methods=['POST'])
def convert_file():
    """API endpoint to convert USDZ file to GLB."""
    if 'file' not in request.files:
        return jsonify({'success': False, 'error': 'No file part'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'success': False, 'error': 'No file selected'}), 400

    # Secure and check the filename
    original_filename = secure_filename(file.filename)
    if not original_filename.lower().endswith('.usdz'):
        return jsonify({'success': False, 'error': 'File must be a .usdz file'}), 400

    # Generate a unique identifier to avoid filename collisions
    unique_id = uuid.uuid4().hex

    # Create unique input and output filenames
    input_filename = f"{os.path.splitext(original_filename)[0]}_{unique_id}.usdz"
    output_filename = f"{os.path.splitext(original_filename)[0]}_{unique_id}.glb"

    # Save the uploaded file with the unique input filename
    input_path = os.path.join(app.config['UPLOAD_FOLDER'], input_filename)
    file.save(input_path)

    # Define the output path with the unique output filename
    output_path = os.path.join(app.config['UPLOAD_FOLDER'], output_filename)

    # Convert the file using our converter module
    result = usdz_to_glb(input_path, output_path)
    if result['success']:
        return send_file(
            output_path,
            as_attachment=True,
            download_name=output_filename,
            mimetype='model/gltf-binary'
        )
    else:
        return jsonify({'success': False, 'error': result.get('error', 'Conversion failed')}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Simple health check endpoint."""
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    app.run(host='0.0.0.0', port=6969, debug=True)
