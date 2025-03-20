import json
import os
import hashlib
from datetime import datetime
import subprocess
import sys
import chardet  # 

# Skript vytvoří dva soubory
### 1 - cloud-difference - rozdíl mezi pravidly v repozitáři a pravidly v sentinelu
### 2 - content-difference - rozdíl mezi contentem v hlavním repozitáři a repozitáři zákazníka

# Návod na spuštění
### python3 -m venv venv
### source venv/bin/activate
### python CustomerScript.py


# Nastavení zákazníka
print("🔹 Nezapomeň se přihlásit k Azure CLI (az login)!")
customer = input("🔹 Název zákazníka: ").strip()

mapping_file = "CustomerAzureValues.json"

# Ověříme, zda soubor existuje
if not os.path.exists(mapping_file):
    print(f"❌ Chyba: Soubor {mapping_file} neexistuje. Vytvoř ho podle ukázky.")
    sys.exit(1)

# Načteme JSON mapování
with open(mapping_file, "r", encoding="utf-8") as f:
    customer_mapping = json.load(f)
    
# Ověříme, zda customer existuje v JSON mapování
if customer not in customer_mapping:
    print(f"❌ Chyba: Zákazník '{customer}' nebyl nalezen v {mapping_file}.")
    sys.exit(1)

# Získáme hodnoty pro resource_group a workspace_name
resource_group = customer_mapping[customer]["resource_group"]
workspace_name = customer_mapping[customer]["workspace_name"]

# Nastavení cest k repozitářům
content_repo = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Content"
customer_repo = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Sentinel-" + customer
customer_rules_repo = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Sentinel-" + customer + "/4-AnalyticRules"

now = datetime.now().strftime("%Y-%m-%d")
CONTENT_DIFFERENCE_FILE = f"content-difference_{customer}_{now}.txt"
CLOUD_DIFFERENCE_FILE = f"cloud-difference_{customer}_{now}.txt"

# Soubory, které ignorujeme
IGNORED_PREFIXES = [".git", ".devops-pipeline"]
IGNORED_SUFFIXES = [".DS_Store", ".README.md", "pipeline.yml"]

# Funkce pro diagnostiku souboru
def diagnose_file(file_path):
    """Zkontroluje encoding, velikost a neviditelné znaky souboru."""
    try:
        with open(file_path, "rb") as f:
            raw_data = f.read()
            encoding_info = chardet.detect(raw_data)
            encoding = encoding_info["encoding"]
            print(f"📂 Diagnostika souboru: {file_path}")
            print(f"🔍 Encoding detekován jako: {encoding}")
            print(f"📏 Velikost souboru: {len(raw_data)} bajtů")
            print(f"🧵 Prvních 200 znaků:\n{raw_data[:200].decode(encoding, errors='replace')}")
            print(f"🛠 Hexdump prvních 20 bajtů:\n{raw_data[:20].hex(' ')}")
    except Exception as e:
        print(f"❌ Chyba při diagnostice souboru: {e}")

# Funkce pro bezpečné načtení JSON souboru
def safe_load_json(file_path):
    try:
        with open(file_path, "r", encoding="utf-8-sig") as f:  # Použití utf-8-sig odstraní BOM
            return json.load(f)  # Normální načtení JSON
    except json.JSONDecodeError as e:
        print(f"❌ JSON Decode Error v souboru: {file_path}")
        print(f"🔍 Chyba: {e}")
        diagnose_file(file_path)
        return None
    except Exception as e:
        print(f"❌ Neznámá chyba při načítání JSON: {file_path}")
        print(f"🛑 {e}")
        diagnose_file(file_path)
        return None

# Funkce pro načtení displayName z JSON souborů
def load_local_rules(directory):
    local_rules = set()
    error_files = []  # Seznam souborů s chybami
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".json"):
                file_path = os.path.join(root, file)
                data = safe_load_json(file_path)  # Použijeme safe_load_json
                if data is None:
                    error_files.append(file_path)
                    continue  # Pokud se nepodařilo načíst, přeskočíme soubor
                
                # Ověříme, že JSON obsahuje pole "resources"
                if "resources" in data and isinstance(data["resources"], list):
                    for resource in data["resources"]:
                        if "properties" in resource and "displayName" in resource["properties"]:
                            local_rules.add(resource["properties"]["displayName"])
                else:
                    error_files.append(file_path)
    return local_rules, error_files

# Funkce pro získání pravidel z Microsoft Sentinelu
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
        print("❌ Chyba při získávání pravidel z Microsoft Sentinelu:", e)
        return set()

def list_files(directory):
    """Vrátí seznam všech souborů v daném adresáři rekurzivně, ignoruje určité složky a soubory."""
    file_list = {}
    for root, _, files in os.walk(directory):
        for file in files:
            full_path = os.path.relpath(os.path.join(root, file), directory)

            # Ignorujeme soubory, které začínají některým z prefixů nebo končí na nežádoucí přípony
            if any(full_path.startswith(prefix) for prefix in IGNORED_PREFIXES) or \
               any(full_path.endswith(suffix) for suffix in IGNORED_SUFFIXES):
                continue
            
            # Ukládáme relativní cestu k souboru a jeho absolutní cestu pro pozdější čtení
            file_list[full_path] = os.path.join(directory, full_path)

    return file_list

def get_file_hash(filepath):
    """Vrátí SHA-256 hash souboru."""
    hasher = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            while chunk := f.read(8192):
                hasher.update(chunk)
        return hasher.hexdigest()
    except Exception as e:
        print(f"❌ Chyba při hashování {filepath}: {e}")
        return None

def insert_blank_lines(sorted_list):
    """Vloží prázdný řádek po změně hlavní kategorie."""
    output = []
    last_category = None

    for file in sorted_list:
        category = file.split('/')[0]  # První část cesty (např. '1-Watchlists')

        if last_category and category != last_category:
            output.append("")  # Přidání prázdného řádku mezi kategoriemi

        output.append(f"+ {file}")
        last_category = category

    return output

def compare_folders(content_repo, customer_repo):
    """Porovná soubory ve dvou repozitářích a uloží rozdíly do souboru."""
    content_files = list_files(content_repo)
    customer_files = list_files(customer_repo)

    only_in_content = sorted(set(content_files) - set(customer_files))
    only_in_customer = sorted(set(customer_files) - set(content_files))
    
    # Soubory se stejným názvem, ale potenciálně jiným obsahem
    common_files = set(content_files) & set(customer_files)
    different_files = []

    for file in sorted(common_files):
        content_hash = get_file_hash(content_files[file])
        customer_hash = get_file_hash(customer_files[file])

        if content_hash and customer_hash and content_hash != customer_hash:
            different_files.append(file)

    with open(CONTENT_DIFFERENCE_FILE, "w", encoding="utf-8") as f:
        f.write("### Soubory pouze v CONTENT repozitáři ###\n\n 🔵 ")
        f.write("\n 🔵 ".join(insert_blank_lines(only_in_content)))

        f.write("\n\n### Soubory pouze v zákaznickém repozitáři ###\n\n 🟠 ")
        f.write("\n 🟠 ".join(insert_blank_lines(only_in_customer)))

        f.write("\n\n### Soubory se stejným názvem, ale jiným obsahem ###\n\n 🟠 ")
        f.write("\n 🟠 ".join(insert_blank_lines(different_files)))

    print(f"✅ Rozdíly mezi repozitářem zákazníka a centrálním repozitářem byly uloženy do {CONTENT_DIFFERENCE_FILE}")


# Načtení pravidel z lokálních souborů a Sentinelu
local_rules, error_files = load_local_rules(customer_rules_repo)
sentinel_rules = load_sentinel_rules(resource_group, workspace_name)

# Porovnání pravidel
missing_in_sentinel = local_rules - sentinel_rules
missing_in_local = sentinel_rules - local_rules

# Výpis výsledků
with open(CLOUD_DIFFERENCE_FILE, "w", encoding="utf-8") as f:
    f.write("### Pravidla pouze lokálně ###\n\n")
    for rule in missing_in_sentinel:
        f.write(f"🟠 {rule}\n")

    f.write("\n### Pravidla pouze v Sentinelu ###\n\n")
    for rule in missing_in_local:
        f.write(f"🔵 {rule}\n")

    print(f"✅ Rozdíly mezi repozitářem zákazníka a Sentinelem byly uloženy do {CLOUD_DIFFERENCE_FILE}")

# Výpis chybných souborů
if error_files:
    print("\n=== Soubory, které nešlo zpracovat ===")
    for file in error_files:
        print(f"❌ {file}")

if __name__ == "__main__":
    compare_folders(content_repo, customer_repo)