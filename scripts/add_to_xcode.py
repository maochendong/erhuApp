#!/usr/bin/env python3
"""Replace the children list and add file/build refs for all WAV files."""

import os, re, uuid

PROJECT = "/Users/Darkknight/Documents/二胡识谱/ErhuApp.xcodeproj/project.pbxproj"
RESOURCES_DIR = "/Users/Darkknight/Documents/二胡识谱/Sources/ErhuApp/Resources"

with open(PROJECT, "r") as f:
    content = f.read()

def uuid24():
    return uuid.uuid4().hex[:24].upper()

# Get WAVs
wav_files = sorted([f for f in os.listdir(RESOURCES_DIR) if f.endswith('.wav')])
print(f"WAV files: {len(wav_files)}")

# Find existing file refs
existing = {}
for m in re.finditer(r'([A-F0-9]{24})\s+\*/\s*=\s*\{[^}]*?isa\s*=\s*PBXFileReference[^}]*?path\s*=\s*([^;]+?)\s*;', content):
    existing[m.group(2).strip()] = m.group(1)

# Generate new entries
new_refs = {}
for wav in wav_files:
    if wav in existing:
        new_refs[wav] = existing[wav]
    else:
        new_refs[wav] = uuid24()

# Build Find & Replace operations
# 1. Replace Resources group children list
old_children = re.search(
    r'(55E35C8E1B2A51438E54E46E\s+\*/\s*=\s*\{[^}]*?children\s*=\s*\()([^)]*)(\))',
    content
)
entries = ''.join(f'\n\t\t\t\t{new_refs[wav]} /* {wav} */,' for wav in wav_files)
new_children_section = old_children.group(1) + entries + '\n\t\t\t' + old_children.group(3)
content = content[:old_children.start()] + new_children_section + content[old_children.end():]
print("Replaced Resources group children")

# 2. Add PBXFileReference entries for new files
for wav in wav_files:
    if wav in existing:
        continue
    # Insert before the closing of objects section
    ref_entry = f'\t\t{new_refs[wav]} /* {wav} */ = {{isa = PBXFileReference; lastKnownFileType = audio.wav; path = {wav}; sourceTree = "<group>"; }};\n'
    # Insert after last file ref
    last_fr = content.rfind('isa = PBXFileReference;')
    insert_pos = content.index('\n', last_fr) + 1 if last_fr >= 0 else len(content) - 10
    content = content[:insert_pos] + ref_entry + content[insert_pos:]
    existing[wav] = new_refs[wav]
    print(f"  Added file ref: {wav}")

# 3. Add PBXBuildFile entries and find Resources build phase
# Find existing build file -> fileRef mapping
build_refs = {}
for m in re.finditer(
    r'([A-F0-9]{24})\s+\*/\s*=\s*\{[^}]*?isa\s*=\s*PBXBuildFile[^}]*?fileRef\s*=\s*([A-F0-9]{24})',
    content
):
    build_refs[m.group(2)] = m.group(1)

# Find resources build phase UUID
rbp_m = re.search(r'([A-F0-9]{24})\s+\*/\s*=\s*\{[^}]*?isa\s*=\s*PBXResourcesBuildPhase', content)
rbp_uuid = rbp_m.group(1)
print(f"Resources phase: {rbp_uuid}")

# Generate build file UUIDs
new_build = {}
for wav in wav_files:
    fr_uuid = new_refs[wav]
    if fr_uuid in build_refs:
        new_build[wav] = build_refs[fr_uuid]
    else:
        new_build[wav] = uuid24()

# Add PBXBuildFile entries
for wav in wav_files:
    fr_uuid = new_refs[wav]
    if fr_uuid in build_refs:
        continue
    bf_uuid = new_build[wav]
    bf_entry = f'\t\t{bf_uuid} /* {wav} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr_uuid} /* {wav} */; }};\n'
    last_bf = content.rfind('isa = PBXBuildFile;')
    insert_pos = content.index('\n', last_bf) + 1 if last_bf >= 0 else len(content) - 10
    content = content[:insert_pos] + bf_entry + content[insert_pos:]
    build_refs[fr_uuid] = bf_uuid
    print(f"  Added build file: {wav}")

# 4. Update Resources build phase files list
bp_m = re.search(
    rf'({rbp_uuid}\s+\*/\s*=\s*\{{[^}}]*?files\s*=\s*\()([^)]*)(\))',
    content
)
new_bp_entries = ''.join(f'\n\t\t\t\t{new_build[wav]} /* {wav} in Resources */,' for wav in wav_files)
new_bp_section = bp_m.group(1) + new_bp_entries + '\n\t\t\t' + bp_m.group(3)
content = content[:bp_m.start()] + new_bp_section + content[bp_m.end():]
print("Updated Resources build phase")

with open(PROJECT, 'w') as f:
    f.write(content)

print("Done!")
PYEOF
