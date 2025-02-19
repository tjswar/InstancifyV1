#!/usr/bin/env python3
import subprocess
import json
from datetime import datetime, timedelta
import re
from collections import defaultdict

def run_command(cmd):
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, error = process.communicate()
    return output.decode(), error.decode(), process.returncode

def parse_image_info(line):
    # Extract image name, digest, and create time from the line
    parts = line.strip().split()
    if len(parts) < 3:
        return None
        
    # Find the full image path (everything before sha256:)
    image_parts = []
    for part in parts:
        if 'sha256:' in part:
            break
        image_parts.append(part)
    
    image_path = ' '.join(image_parts).strip()
    
    # Extract function name from the path
    match = re.search(r'instancify__us--central1__([^/]+)', image_path)
    if not match:
        return None
    function_name = match.group(1)
    
    # Find the digest
    digest = next((part for part in parts if part.startswith('sha256:')), None)
    if not digest:
        return None
        
    # Find the create time
    try:
        create_time = next(part for part in parts if 'T' in part and len(part) > 15)
        create_time = datetime.strptime(create_time, '%Y-%m-%dT%H:%M:%S')
    except (StopIteration, ValueError):
        return None
        
    return {
        'function_name': function_name,
        'full_image': image_path,
        'digest': digest,
        'create_time': create_time
    }

def main():
    # Get list of images
    output, error, rc = run_command('gcloud artifacts docker images list us-central1-docker.pkg.dev/instancify/gcf-artifacts')
    if rc != 0:
        print(f"Error getting image list: {error}")
        return

    # Group images by function
    images_by_function = defaultdict(list)
    
    for line in output.splitlines():
        image_info = parse_image_info(line)
        if image_info:
            images_by_function[image_info['function_name']].append(image_info)

    # Process each function's images
    cutoff_time = datetime.now() - timedelta(hours=24)
    deleted_count = 0
    kept_count = 0
    
    for function_name, images in images_by_function.items():
        # Sort by creation time, newest first
        images.sort(key=lambda x: x['create_time'], reverse=True)
        
        # Keep track of the newest image
        if images:
            newest = images[0]
            kept_count += 1
            print(f"\nKeeping newest image for {function_name}:")
            print(f"  Created: {newest['create_time']}")
            print(f"  Image: {newest['full_image']}@{newest['digest']}")
            
            # Delete older images
            for image in images[1:]:
                if image['create_time'] < cutoff_time:
                    full_image_ref = f"{image['full_image']}@{image['digest']}"
                    print(f"\nDeleting old image:")
                    print(f"  Function: {function_name}")
                    print(f"  Created: {image['create_time']}")
                    print(f"  Image: {full_image_ref}")
                    
                    cmd = f"gcloud artifacts docker images delete {full_image_ref} --quiet"
                    output, error, rc = run_command(cmd)
                    if rc == 0:
                        deleted_count += 1
                    else:
                        print(f"Error deleting image: {error}")
                else:
                    kept_count += 1

    print(f"\nCleanup complete:")
    print(f"Images deleted: {deleted_count}")
    print(f"Images kept: {kept_count}")

if __name__ == '__main__':
    main() 