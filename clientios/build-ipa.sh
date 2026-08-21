#!/usr/bin/env bash

# build-ipa.sh — Génère un .ipa non signé de l'app Tracker, à installer via AltStore
# (AltStore re-signe l'app lui-même, inutile de la signer ici)
# Usage: ./build-ipa.sh [--version X.Y.Z] [--build N] [--output <dir>]

set -euo pipefail

cd "$(dirname "$0")"

PROJECT="Tracker.xcodeproj"
SCHEME="Tracker"
CONFIGURATION="Release"
OUTPUT_DIR="build"
MARKETING_VERSION=""
BUILD_NUMBER=""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}🔄 $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

usage() {
    cat <<EOF
Usage: $0 [options]

Build non signé du scheme ${SCHEME} et assemblage du .ipa dans ./${OUTPUT_DIR}/.
L'archive obtenue s'installe avec AltStore / Sideloadly, qui la re-signent.

Options:
  --version <X.Y.Z>    Écrase MARKETING_VERSION pour ce build.
  --build <N>          Écrase CURRENT_PROJECT_VERSION pour ce build.
  --output <dir>       Dossier de sortie (défaut: ${OUTPUT_DIR}).
  -h, --help           Affiche cette aide.

Exemples:
  $0
  $0 --version 1.1.0 --build 42
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) MARKETING_VERSION="$2"; shift 2 ;;
        --build) BUILD_NUMBER="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) print_error "Option inconnue: $1"; usage; exit 1 ;;
    esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
    print_error "xcodebuild introuvable. Installez Xcode et lancez: xcode-select --install"
    exit 1
fi

DERIVED_DATA="${OUTPUT_DIR}/DerivedData"
IPA_PATH="${OUTPUT_DIR}/${SCHEME}.ipa"

rm -f "${IPA_PATH}"
mkdir -p "${OUTPUT_DIR}"

# Surcharges de version, appliquées uniquement à ce build (le .pbxproj n'est pas modifié)
VERSION_ARGS=()
[ -n "${MARKETING_VERSION}" ] && VERSION_ARGS+=("MARKETING_VERSION=${MARKETING_VERSION}")
[ -n "${BUILD_NUMBER}" ] && VERSION_ARGS+=("CURRENT_PROJECT_VERSION=${BUILD_NUMBER}")

print_step "Build non signé de ${SCHEME} (${CONFIGURATION})"

xcodebuild build \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "${DERIVED_DATA}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGN_ENTITLEMENTS="" \
    ${VERSION_ARGS[@]+"${VERSION_ARGS[@]}"} \
    | grep -E '^(\*\*|error:|warning: .*deprecated)' || true

APP_PATH="${DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphoneos/${SCHEME}.app"
if [ ! -d "${APP_PATH}" ]; then
    print_error "App introuvable après le build: ${APP_PATH}"
    exit 1
fi

print_step "Assemblage du .ipa (Payload/)"
PAYLOAD_DIR=$(mktemp -d)
mkdir -p "${PAYLOAD_DIR}/Payload"
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/Payload/"
IPA_ABS="$(cd "${OUTPUT_DIR}" && pwd)/${SCHEME}.ipa"
(cd "${PAYLOAD_DIR}" && zip -qry "${IPA_ABS}" Payload)
rm -rf "${PAYLOAD_DIR}"

SIZE=$(du -h "${IPA_PATH}" | cut -f1)
print_success "IPA généré: ${IPA_PATH} (${SIZE})"

echo ""
echo "📦 ${IPA_ABS}"
echo "💡 Ouvre-le avec AltStore (AltServer > Install .ipa, ou partage vers AltStore depuis l'iPhone)."

exit 0
