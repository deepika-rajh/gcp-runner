#!/bin/bash
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo "=============================================="
echo "     QCS6490 DEV FEATURE BUILD STARTED        "
echo "=============================================="

WORKDIR="/home/cto/qcs_builds/development"
REPO_DIR="/home/cto/actions-runner/deployement/hsv2_core/hsv2_core"

mkdir -p "$WORKDIR"

cd "$REPO_DIR" || exit 1

echo " Fetching latest dev branch..."
git fetch origin development
git checkout development

echo " Searching for features with build.sh..."
FEATURES=$(find . -maxdepth 3 -type f -name "build.sh" | sed 's#/build.sh##')

echo "Found features:"
echo "$FEATURES"
echo ""

BUILD_FAILED=0

# =======================================================================
# LOOP FOR EACH FEATURE
# =======================================================================

for FEATURE in $FEATURES; do
    FEATURE_NAME=$(basename "$FEATURE")

    echo "=============================================="
    echo " Building FEATURE: $FEATURE_NAME"
    echo "=============================================="

    cd "$FEATURE" || continue

    # -------------------------------------------------------
    # Prepare environment
    # -------------------------------------------------------
    echo " Cleaning LD_LIBRARY_PATH"
    unset LD_LIBRARY_PATH

    echo " Loading QCS6490 environment..."
    source /opt/qcom-wayland_sdk/environment-setup-armv8-2a-qcom-linux
    echo " Environment ready"

    # -------------------------------------------------------
    # Run build.sh
    # -------------------------------------------------------
    echo " Running build.sh..."
    chmod +x build.sh
    ./build.sh

    # -------------------------------------------------------
    # VALIDATION FOR THIS FEATURE
    # -------------------------------------------------------
    VALID=1

    echo "----------------------------------------------"
    echo " VALIDATING BUILD OUTPUT FOR: $FEATURE_NAME"
    echo "----------------------------------------------"

    # build/ folder must exist
    if [ ! -d "build" ]; then
        echo " ERROR: build/ folder NOT found for $FEATURE_NAME"
        VALID=0
    fi

    # at least one binary file must exist
    BINARIES=$(find build -maxdepth 1 -type f -executable)
    if [ -z "$BINARIES" ]; then
        echo " ERROR: No executable binary found in build/ for $FEATURE_NAME"
        VALID=0
    else
        echo " Executable(s) found:"
        echo "$BINARIES"
    fi

    # CMake files must exist
    CMAKE_OK=1
    if [ ! -f "build/CMakeCache.txt" ]; then CMAKE_OK=0; fi
    if [ ! -f "build/cmake_install.cmake" ]; then CMAKE_OK=0; fi
    if [ ! -f "build/Makefile" ] && [ ! -f "build/build.ninja" ]; then CMAKE_OK=0; fi

    if [ "$CMAKE_OK" -eq 0 ]; then
        echo " ERROR: Missing required CMake files in $FEATURE_NAME/build/"
        VALID=0
    else
        echo " CMake files validated."
    fi

    # -------------------------------------------------------
    # Evaluate validation result for this feature
    # -------------------------------------------------------
    if [ "$VALID" -eq 0 ]; then
        echo " FEATURE FAILED: $FEATURE_NAME"
        BUILD_FAILED=1
    else
        echo " FEATURE PASSED: $FEATURE_NAME"

        # Save build output
        TARGET="$WORKDIR/$FEATURE_NAME"
        mkdir -p "$TARGET"
        cp -r build/* "$TARGET/"
    fi

    # Return to repo root
    cd "$REPO_DIR"
done

# =======================================================================
# CREATE FINAL ZIP ARCHIVE (ALL FEATURES)
# =======================================================================

FINAL_ZIP="/home/cto/qcs_builds/final_development_build.zip"

echo "=============================================="
echo " Creating FINAL ZIP PACKAGE"
echo "=============================================="

# Remove old zip if exists
rm -f "$FINAL_ZIP"

cd /home/cto/qcs_builds

zip -r "$FINAL_ZIP" development >/dev/null

if [ $? -ne 0 ]; then
    echo " ERROR: Failed to create FINAL ZIP archive"
    BUILD_FAILED=1
else
    echo " FINAL ZIP CREATED SUCCESSFULLY:"
    echo " ➤ $FINAL_ZIP"
fi

# =======================================================================
# FINAL RESULT
# =======================================================================

echo "=============================================="
echo "           FINAL BUILD VERIFICATION           "
echo "=============================================="

if [ $BUILD_FAILED -eq 1 ]; then
    echo " One or more features FAILED validation."
    exit 1
else
    echo " ALL FEATURES PASSED SUCCESSFULLY!"
    echo " Final ZIP available at: $FINAL_ZIP"
    exit 0
fi
