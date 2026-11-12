#!/bin/bash
# Prepare a Husk tree for HOC-focused CI / cloud builds:
# - keep Gameloft/HOC EGL patches in source
# - skip MoltenVK (not needed for HOC; Unreal/Vulkan only)
# - stub Built-in StikJIT helper (prebuilt xcframework breaks on Xcode 26+)
# - make package_ipa.sh use a generic iOS destination
set -euo pipefail

HUSK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HUSK_ROOT"

echo "==> HOC prepare in $HUSK_ROOT"

# --- MoltenVK: comment out of project.yml; placeholder so ci_build skips build ---
python3 - <<'PY'
from pathlib import Path
p = Path("src/app/project.yml")
t = p.read_text()
needle = "      - framework: ../../build/ios-arm64/lib/MoltenVK.xcframework\n"
if needle in t:
    t = t.replace(
        needle,
        "      # MoltenVK skipped for HOC CI (Unreal/Vulkan only)\n",
        1,
    )
    p.write_text(t)
    print("project.yml: MoltenVK removed")
elif "MoltenVK skipped for HOC" in t:
    print("project.yml: MoltenVK already skipped")
else:
    print("project.yml: MoltenVK line not found (ok if already gone)")
PY

mkdir -p build/ios-arm64/lib/MoltenVK.xcframework

# Strip any remaining MoltenVK refs from checked-in pbxproj (xcodegen may regenerate later).
python3 - <<'PY'
from pathlib import Path
p = Path("src/app/Husk.xcodeproj/project.pbxproj")
if not p.exists():
    raise SystemExit(0)
t = p.read_text()
lines = []
for line in t.splitlines(True):
    if "MoltenVK" in line:
        continue
    lines.append(line)
new = "".join(lines)
if new != t:
    p.write_text(new)
    print("pbxproj: stripped MoltenVK lines")
else:
    print("pbxproj: no MoltenVK lines")
PY

# --- StikJIT helper stub (use external StikDebug on device) ---
HELPER="src/app/HuskJITHelper/HuskJITHelper.swift"
if [ -f "$HELPER" ]; then
    cp "$HELPER" "${HELPER}.pre-hoc-ci.bak" 2>/dev/null || true
fi
cat > "$HELPER" <<'EOF'
import Foundation

/// HOC CI stub: bundled StikJIT.xcframework is not compatible with Xcode 26's
/// Swift module format. Use external StikDebug for JIT on device.
@main
struct HuskJITHelperMain {
    static func main() {
        exit(0)
    }
}
EOF
echo "HuskJITHelper.swift: stubbed"

# If @main already exists elsewhere in the helper target, drop ours and use empty type.
if grep -rn "@main" src/app/HuskJITHelper --include='*.swift' | grep -v HuskJITHelper.swift | grep -q .; then
    cat > "$HELPER" <<'EOF'
import Foundation

enum HuskJITHelperStub {
    static func noop() {}
}
EOF
    echo "HuskJITHelper.swift: stub without @main (another @main present)"
fi

# --- package_ipa: require scheme + generic iOS destination (Xcode 26) ---
python3 - <<'PY'
from pathlib import Path
p = Path("scripts/package_ipa.sh")
t = p.read_text()
old = '''xcodebuild -project "$HUSK_ROOT/src/app/Husk.xcodeproj" -scheme Husk \\
    -sdk iphoneos -configuration Release -derivedDataPath "$DD" \\
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \\
    build'''
new = '''xcodebuild -project "$HUSK_ROOT/src/app/Husk.xcodeproj" -scheme Husk \\
    -sdk iphoneos -destination 'generic/platform=iOS' -configuration Release -derivedDataPath "$DD" \\
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \\
    ONLY_ACTIVE_ARCH=NO \\
    build'''
if old in t:
    p.write_text(t.replace(old, new, 1))
    print("package_ipa.sh: destination + ONLY_ACTIVE_ARCH added")
elif "generic/platform=iOS" in t:
    print("package_ipa.sh: already patched")
else:
    print("package_ipa.sh: xcodebuild block not found — edit manually")
PY

# Sanity: HOC markers still present
if grep -q "e2_force_readback\|hoc/gameloft" src/translation-layer-next/husk-tl-dvm-android.c; then
    echo "==> HOC / gameloft patch markers: OK"
else
    echo "==> WARNING: HOC patch markers not found in husk-tl-dvm-android.c" >&2
fi

echo "==> ci_prepare_hoc done"
