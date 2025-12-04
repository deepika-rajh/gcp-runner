#!/bin/bash

# -----------------------------------------
# GitHub Repo Configuration
# -----------------------------------------
GITHUB_OWNER="hearsightai"
GITHUB_REPO="hsv2_core"
ZIP_NAME="final_development_build.zip"

# -----------------------------------------
# Local Destination (destination server)
# -----------------------------------------
DEST_DIR="/home/advantech/github_release_build"
TOKEN_FILE="$HOME/.github_token"

# -----------------------------------------
# Dev Kit (Target device)
# -----------------------------------------
DEVKIT_USER="root"
DEVKIT_IP="192.168.0.187"
DEVKIT_DEST="/home/root/deployment_binary/"

mkdir -p "$DEST_DIR"
cd "$DEST_DIR"

echo "=============================================="
echo " Checking GitHub Token..."
echo "=============================================="

if [ ! -f "$TOKEN_FILE" ]; then
    echo " ERROR: GitHub token not found at $TOKEN_FILE"
    exit 1
fi

GITHUB_TOKEN=$(cat "$TOKEN_FILE")

echo "=============================================="
echo " Fetching latest GitHub release metadata..."
echo "=============================================="

# Fetch authenticated release metadata
RELEASE_JSON=$(curl -H "Authorization: token $GITHUB_TOKEN" \
  -s "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/releases/latest")

echo ""
echo "Release metadata received ✔"
echo ""

# Extract ASSET API URL (NOT browser_download_url)
ASSET_URL=$(echo "$RELEASE_JSON" | grep '"url"' | grep 'assets/' | cut -d '"' -f 4)

if [ -z "$ASSET_URL" ]; then
    echo " ERROR: Could not extract asset API URL from release metadata."
    echo "Full release JSON:"
    echo "$RELEASE_JSON"
    exit 1
fi

echo "Asset API URL:"
echo "$ASSET_URL"
echo ""

echo "----------------------------------------------"
echo " Downloading REAL ZIP using GitHub API..."
echo "----------------------------------------------"

# Download the real ZIP from asset API URL
curl -L \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/octet-stream" \
  "$ASSET_URL" \
  --output "$ZIP_NAME"

if [ $? -ne 0 ]; then
    echo " ERROR: Failed to download ZIP file."
    exit 1
fi

echo ""
echo "=============================================="
echo " ZIP Download Complete!"
echo " File saved to:"
echo "   $DEST_DIR/$ZIP_NAME"
echo "=============================================="
echo ""

echo "----------------------------------------------"
echo " Copying ZIP to Dev Kit ($DEVKIT_IP)..."
echo " Target Path:"
echo "   ${DEVKIT_DEST}"
echo "----------------------------------------------"

scp "$ZIP_NAME" ${DEVKIT_USER}@${DEVKIT_IP}:${DEVKIT_DEST}

if [ $? -ne 0 ]; then
    echo " ERROR: SCP transfer to Dev Kit FAILED!"
    exit 1
fi

echo ""
echo "=============================================="
echo " SUCCESS!!! ZIP delivered to Dev Kit ✔"
echo " Saved at:"
echo "   ${DEVKIT_DEST}${ZIP_NAME}"
echo "=============================================="
