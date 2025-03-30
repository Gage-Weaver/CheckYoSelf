import os
import sys
import subprocess
import tempfile
from pathlib import Path
import json

def find_blender_executable():
    """Try to find the Blender executable on different platforms."""
    potential_paths = [
        # Windows
        r"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 3.5\blender.exe",
        # macOS
        "/Applications/Blender.app/Contents/MacOS/Blender",
        # Linux
        "/usr/bin/blender",
        "/usr/local/bin/blender",
    ]
    for path in potential_paths:
        if os.path.exists(path):
            return path

    # Try to find it in PATH
    try:
        result = subprocess.run(["which", "blender"], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass

    return None

def usdz_to_glb(input_file, output_file=None):
    """
    Convert a USDZ file to GLB using Blender's Python API.

    Args:
        input_file (str): Path to the input USDZ file.
        output_file (str, optional): Path for the output GLB file. If not provided, the input file name is used with a .glb extension.

    Returns:
        dict: A dictionary with a 'success' key (True/False) and additional info or error message.
    """
    input_path = Path(input_file)
    if not input_path.exists():
        return {"success": False, "error": f"Input file not found: {input_file}"}
    if input_path.suffix.lower() != ".usdz":
        return {"success": False, "error": f"Input file is not a USDZ file: {input_file}"}

    if output_file is None:
        output_file = str(input_path.with_suffix(".glb"))

    # Create a temporary Blender Python script for conversion
    with tempfile.NamedTemporaryFile(suffix=".py", delete=False, mode="w") as blender_script:
        blender_script.write("""
import bpy
import sys

# Get arguments passed after '--'
argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_file = argv[0]
output_file = argv[1]

# Reset Blender to factory settings
bpy.ops.wm.read_factory_settings(use_empty=True)

# Import the USDZ file
bpy.ops.wm.usd_import(filepath=input_file)

# Export the scene as GLB
bpy.ops.export_scene.gltf(filepath=output_file, export_format='GLB')

print("Conversion completed")
""")
        blender_script_name = blender_script.name

    blender_executable = find_blender_executable()
    if not blender_executable:
        os.unlink(blender_script_name)
        return {"success": False, "error": "Could not find Blender executable. Please install Blender or provide the path manually."}

    try:
        cmd = [
            blender_executable,
            "--background",
            "--python", blender_script_name,
            "--", input_file, output_file
        ]
        process = subprocess.run(
            cmd,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        if os.path.exists(output_file):
            return {
                "success": True,
                "input_file": input_file,
                "output_file": output_file,
                "stdout": process.stdout,
                "stderr": process.stderr
            }
        else:
            return {
                "success": False,
                "error": "Conversion process completed but output file was not created.",
                "stdout": process.stdout,
                "stderr": process.stderr
            }
    except subprocess.CalledProcessError as e:
        return {
            "success": False,
            "error": f"Blender process failed with exit code {e.returncode}",
            "stdout": e.stdout,
            "stderr": e.stderr
        }
    finally:
        os.unlink(blender_script_name)

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Convert USDZ files to GLB format using Blender")
    parser.add_argument("input_file", help="Path to the input USDZ file")
    parser.add_argument("-o", "--output", help="Path for the output GLB file (optional)")
    args = parser.parse_args()
    result = usdz_to_glb(args.input_file, args.output)
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["success"] else 1)

if __name__ == "__main__":
    main()
