import json
import os
import hashlib
from datetime import datetime
import subprocess
import sys
import chardet  # 

# The script creates two files:
### 1 - cloud-difference - the difference between rules in the repository and rules in Sentinel
### 2 - content-difference - the difference between content in the main repository and the customer's repository

# Customer configuration
print("🔹 Don't forget to log in to Azure CLI (az login)!")
customer = input("🔹 Customer name: ").strip()

mapping_file = "CustomerAzureValues.json"

# Verify if the file exists
if not os.path.exists(mapping_file):
    print(f"❌ Error: The file {mapping_file} does not exist. Create it according to the example.")
    sys.exit(1)

# Load JSON mapping
with open(mapping_file, "r", encoding="utf-8") as f:
    customer_mapping = json.load(f)
    
# Verify if the customer exists in the JSON mapping
if customer not in customer_mapping:
    print(f"❌ Error: Customer '{customer}' was not found in {mapping_file}.")
    sys.exit(1)

# Retrieve values for resource_group and workspace_name
resource_group = customer_mapping[customer]["resource_group"]
workspace_name = customer_mapping[customer]["workspace_name"]

# Set paths to repositories
content_repo = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Content"
customer_repo = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Sentinel-" + customer
customer_rules_repo = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Sentinel-" + customer + "/4-AnalyticRules"

now = datetime.now().strftime("%Y-%m-%d")
CONTENT_DIFFERENCE_FILE = f"content-difference_{customer}_{now}.txt"
CLOUD_DIFFERENCE_FILE = f"cloud-difference_{customer}_{now}.txt"

# Files to be ignored
IGNORED_PREFIXES = [".git", ".devops-pipeline"]
IGNORED_SUFFIXES = [".DS_Store", ".README.md", "pipeline.yml"]

# Function for file diagnostics
def diagnose_file(file_path):
    """Checks encoding, file size, and invisible characters."""
    try:
        with open(file_path, "rb") as f:
            raw_data = f.read()
            encoding_info = chardet.detect(raw_data)
            encoding = encoding_info["encoding"]
            print(f"📂 File diagnostics: {file_path}")
            print(f"🔍 Encoding detected as: {encoding}")
            print(f"📏 File size: {len(raw_data)} bytes")
            print(f"🧵 First 200 characters:\n{raw_data[:200].decode(encoding, errors='replace')}")
            print(f"🛠 Hexdump of the first 20 bytes:\n{raw_data[:20].hex(' ')}")
    except Exception as e:
        print(f"❌ Error during file diagnostics: {e}")

# Function for safely loading a JSON file
def safe_load_json(file_path):
    try:
        with open(file_path, "r", encoding="utf-8-sig") as f:  # Using utf-8-sig removes BOM
            return json.load(f)  # Normal JSON loading
    except json.JSONDecodeError as e:
        print(f"❌ JSON Decode Error in file: {file_path}")
        print(f"🔍 Error: {e}")
        diagnose_file(file_path)
        return None
    except Exception as e:
        print(f"❌ Unknown error while loading JSON: {file_path}")
        print(f"🛑 {e}")
        diagnose_file(file_path)
        return None

# Function to load displayName from JSON files
def load_local_rules(directory):
    local_rules = set()
    error_files = []  # List of files with errors
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".json"):
                file_path = os.path.join(root, file)
                data = safe_load_json(file_path)  # Use safe_load_json
                if data is None:
                    error_files.append(file_path)
                    continue  # Skip the file if it couldn't be loaded
                
                # Verify that the JSON contains the "resources" field
                if "resources" in data and isinstance(data["resources"], list):
                    for resource in data["resources"]:
                        if "properties" in resource and "displayName" in resource["properties"]:
                            local_rules.add(resource["properties"]["displayName"])
                else:
                    error_files.append(file_path)
    return local_rules, error_files

# Function to retrieve rules from Microsoft Sentinel
def load_sentinel_rules(resource_group, workspace_name):
    try:
        command = [
            "az", "sentinel", "alert-rule", "list",
            "--resource-group", resource_group,
            "--workspace-name", workspace_name,
            "--query", "[].displayName",
            "--output", "json"
        ]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return set(json.loads(result.stdout))
    except subprocess.CalledProcessError as e:
        print("❌ Error retrieving rules from Microsoft Sentinel:", e)
        return set()

def list_files(directory):
    """Returns a list of all files in the given directory recursively, ignoring certain folders and files."""
    file_list = {}
    for root, _, files in os.walk(directory):
        for file in files:
            full_path = os.path.relpath(os.path.join(root, file), directory)

            # Ignore files that start with any of the prefixes or end with unwanted extensions
            if any(full_path.startswith(prefix) for prefix in IGNORED_PREFIXES) or \
               any(full_path.endswith(suffix) for suffix in IGNORED_SUFFIXES):
                continue
            
            # Store the relative path to the file and its absolute path for later reading
            file_list[full_path] = os.path.join(directory, full_path)

    return file_list

def get_file_hash(filepath):
    """Returns the SHA-256 hash of a file."""
    hasher = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            while chunk := f.read(8192):
                hasher.update(chunk)
        return hasher.hexdigest()
    except Exception as e:
        print(f"❌ Error hashing {filepath}: {e}")
        return None

def insert_blank_lines(sorted_list):
    """Inserts a blank line after a change in the main category."""
    output = []
    last_category = None

    for file in sorted_list:
        category = file.split('/')[0]  # First part of the path (e.g., '1-Watchlists')

        if last_category and category != last_category:
            output.append("")  # Add a blank line between categories

        output.append(f"+ {file}")
        last_category = category

    return output

def compare_folders(content_repo, customer_repo):
    """Compares files in two repositories and saves the differences to a file."""
    content_files = list_files(content_repo)
    customer_files = list_files(customer_repo)

    only_in_content = sorted(set(content_files) - set(customer_files))
    only_in_customer = sorted(set(customer_files) - set(content_files))
    
    # Files with the same name but potentially different content
    common_files = set(content_files) & set(customer_files)
    different_files = []

    for file in sorted(common_files):
        content_hash = get_file_hash(content_files[file])
        customer_hash = get_file_hash(customer_files[file])

        if content_hash and customer_hash and content_hash != customer_hash:
            different_files.append(file)

    with open(CONTENT_DIFFERENCE_FILE, "w", encoding="utf-8") as f:
        f.write("### Files only in the CONTENT repository ###\n\n 🔵 ")
        f.write("\n 🔵 ".join(insert_blank_lines(only_in_content)))

        f.write("\n\n### Files only in the customer repository ###\n\n 🟠 ")
        f.write("\n 🟠 ".join(insert_blank_lines(only_in_customer)))

        f.write("\n\n### Files with the same name but different content ###\n\n 🟠 ")
        f.write("\n 🟠 ".join(insert_blank_lines(different_files)))

    print(f"✅ Differences between the customer repository and the central repository have been saved to {CONTENT_DIFFERENCE_FILE}")