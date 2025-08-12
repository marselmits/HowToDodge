import os, json, subprocess, shutil, re, sys

ROOT = os.path.dirname(os.path.dirname(__file__))
SRC = os.path.join(ROOT, "src_images")
META = os.path.join(ROOT, "meta", "labels.json")
ADDON = os.path.join(ROOT, "addon")
PLANS = os.path.join(ADDON, "media", "plans")
DATA  = os.path.join(ADDON, "data")
TOC   = os.path.join(ADDON, "HowToDodge.toc")

def natural_key(s):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r'(\d+)', s)]

def ensure_dirs():
    os.makedirs(PLANS, exist_ok=True)
    os.makedirs(DATA, exist_ok=True)

def convert_to_tga(src, dst):
    # unkomprimiertes TGA, ohne RLE
    subprocess.check_call(["convert", src, "-compress", "none", dst])

def image_size(path):
    out = subprocess.check_output(["identify", "-format", "%w %h", path], text=True).strip()
    w, h = out.split()
    return int(w), int(h)

def build_labels():
    if os.path.exists(META):
        with open(META, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def sanitize_key(name):
    return re.sub(r'[^a-z0-9_]', "", name.lower())

def write_plans_lua(bosses):
    lua_path = os.path.join(DATA, "HTD_Plans.lua")
    with open(lua_path, "w", encoding="utf-8") as f:
        f.write("-- auto-generated, do not edit\n")
        f.write("HowToDodgePlans = {\n")
        for b in bosses:
            f.write(f'  {{ key = "{b["key"]}", label = "{b["label"]}", pages = {{\n')
            for p in b["pages"]:
                f.write('    { label = "%s", file = "%s", width = %d, height = %d },\n' %
                        (p["label"], p["file"].replace("\\", "\\\\"), p["width"], p["height"]))
            f.write("  }},\n")
        f.write("}\n")

def replace_version(version):
    with open(TOC, "r", encoding="utf-8") as f:
        s = f.read()
    s = s.replace("@VERSION@", version)
    with open(TOC, "w", encoding="utf-8") as f:
        f.write(s)

def main():
    ensure_dirs()
    labels = build_labels()
    bosses = []

    if not os.path.isdir(SRC):
        print("no src_images directory", file=sys.stderr)
        sys.exit(1)

    for boss_dir in sorted(os.listdir(SRC), key=natural_key):
        bpath = os.path.join(SRC, boss_dir)
        if not os.path.isdir(bpath):
            continue
        key = sanitize_key(boss_dir)
        label = labels.get(key, boss_dir)

        pages = []
        files = [f for f in os.listdir(bpath) if re.search(r'\.(png|jpg|jpeg)$', f, re.I)]
        files.sort(key=natural_key)
        for idx, fname in enumerate(files, 1):
            src_path = os.path.join(bpath, fname)
            out_name = f"{key}_{idx}.tga"
            dst_path = os.path.join(PLANS, out_name)
            convert_to_tga(src_path, dst_path)
            w, h = image_size(dst_path)
            pages.append({
                "label": f"Seite {idx}",
                "file": f"Interface\\AddOns\\HowToDodge\\media\\plans\\{out_name}",
                "width": w,
                "height": h
            })

        if pages:
            bosses.append({"key": key, "label": label, "pages": pages})

    version = os.environ.get("GITHUB_SHA", "")[:7] or "dev"
    replace_version(version)
    write_plans_lua(bosses)

if __name__ == "__main__":
    main()
