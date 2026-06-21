#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export ASPNETCORE_ENVIRONMENT="${ASPNETCORE_ENVIRONMENT:-Development}"
export DOTNET_ENVIRONMENT="${DOTNET_ENVIRONMENT:-$ASPNETCORE_ENVIRONMENT}"

dotnet run --project "$APP_DIR/TrackerApi.csproj" -- --backfill-seen-media-metadata "$@"
