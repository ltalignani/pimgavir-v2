#!/bin/bash

################################################################################
# Test Pilon Memory Configuration
#
# Purpose: Verify Pilon can allocate sufficient memory
# Usage: bash test_pilon_memory.sh
################################################################################

echo "=========================================="
echo "Pilon Memory Configuration Test"
echo "=========================================="
echo ""

# Check if conda environment is activated
if [[ "$CONDA_DEFAULT_ENV" != "pimgavir_viralgenomes" ]] && \
   [[ "$CONDA_DEFAULT_ENV" != "pimgavir_complete" ]] && \
   [[ "$CONDA_DEFAULT_ENV" != "pimgavir_minimal" ]]; then
    echo "⚠️  WARNING: PIMGAVir conda environment not detected"
    echo "Please activate environment first:"
    echo "  conda activate pimgavir_viralgenomes"
    echo ""
fi

# Check if pilon is available
echo "1. Checking Pilon installation..."
if command -v pilon &> /dev/null; then
    PILON_PATH=$(which pilon)
    echo "   ✅ Pilon found: $PILON_PATH"

    # Get Pilon version
    pilon --version 2>&1 | head -1
else
    echo "   ❌ ERROR: Pilon not found in PATH"
    echo "   Install with: conda install -c bioconda pilon"
    exit 1
fi
echo ""

# Check Java version
echo "2. Checking Java installation..."
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -1)
    echo "   ✅ Java found: $JAVA_VERSION"
else
    echo "   ❌ ERROR: Java not found in PATH"
    echo "   Java is required for Pilon"
    exit 1
fi
echo ""

# Test default Java memory
echo "3. Testing default Java memory allocation..."
DEFAULT_MEMORY=$(java -XX:+PrintFlagsFinal -version 2>&1 | grep MaxHeapSize | awk '{print $4}')
DEFAULT_MEMORY_GB=$((DEFAULT_MEMORY / 1024 / 1024 / 1024))
echo "   Default MaxHeapSize: ${DEFAULT_MEMORY_GB} GB"
if [[ $DEFAULT_MEMORY_GB -lt 8 ]]; then
    echo "   ⚠️  WARNING: Default heap size is low (<8 GB)"
    echo "   Pilon may fail on large datasets without explicit memory allocation"
else
    echo "   ✅ Default heap size is reasonable"
fi
echo ""

# Test _JAVA_OPTIONS override
echo "4. Testing _JAVA_OPTIONS memory override..."
export _JAVA_OPTIONS="-Xmx32g"
echo "   Set: _JAVA_OPTIONS=\"$_JAVA_OPTIONS\""

# Run a simple Java command to verify memory setting
OVERRIDE_TEST=$(java -XX:+PrintFlagsFinal -version 2>&1 | grep MaxHeapSize | awk '{print $4}')
OVERRIDE_TEST_GB=$((OVERRIDE_TEST / 1024 / 1024 / 1024))
echo "   Effective MaxHeapSize: ${OVERRIDE_TEST_GB} GB"

if [[ $OVERRIDE_TEST_GB -ge 30 ]]; then
    echo "   ✅ Memory override successful (≥30 GB)"
else
    echo "   ⚠️  WARNING: Memory override may not be working as expected"
    echo "   Expected ~32 GB, got ${OVERRIDE_TEST_GB} GB"
fi
unset _JAVA_OPTIONS
echo ""

# Check system memory
echo "5. Checking system memory availability..."
if command -v free &> /dev/null; then
    TOTAL_MEMORY=$(free -g | grep Mem | awk '{print $2}')
    AVAIL_MEMORY=$(free -g | grep Mem | awk '{print $7}')
    echo "   Total memory: ${TOTAL_MEMORY} GB"
    echo "   Available memory: ${AVAIL_MEMORY} GB"

    if [[ $AVAIL_MEMORY -ge 32 ]]; then
        echo "   ✅ Sufficient memory for Pilon (≥32 GB available)"
    elif [[ $AVAIL_MEMORY -ge 16 ]]; then
        echo "   ⚠️  WARNING: Limited memory (16-32 GB available)"
        echo "   May need to reduce Pilon memory allocation or use smaller datasets"
    else
        echo "   ❌ ERROR: Insufficient memory (<16 GB available)"
        echo "   Pilon likely to fail. Consider:"
        echo "   - Using a high-memory node"
        echo "   - Reducing dataset size"
        echo "   - Skipping Pilon polishing"
    fi
else
    echo "   ⚠️  Cannot check system memory (free command not available)"
fi
echo ""

# Check assembly_conda.sh configuration
echo "6. Checking assembly_conda.sh Pilon configuration..."
ASSEMBLY_SCRIPT="scripts/assembly_conda.sh"
if [[ -f "$ASSEMBLY_SCRIPT" ]]; then
    if grep -q "export _JAVA_OPTIONS" "$ASSEMBLY_SCRIPT"; then
        MEMORY_SETTING=$(grep "export _JAVA_OPTIONS" "$ASSEMBLY_SCRIPT" | head -1)
        echo "   ✅ Memory allocation found: $MEMORY_SETTING"

        # Extract memory value
        MEMORY_VALUE=$(echo "$MEMORY_SETTING" | grep -oP '(?<=-Xmx)\d+' || echo "unknown")
        if [[ "$MEMORY_VALUE" != "unknown" ]] && [[ $MEMORY_VALUE -ge 32 ]]; then
            echo "   ✅ Memory allocation is adequate (≥32 GB)"
        elif [[ "$MEMORY_VALUE" != "unknown" ]]; then
            echo "   ⚠️  WARNING: Memory allocation may be low (${MEMORY_VALUE} GB)"
        fi
    else
        echo "   ❌ WARNING: No explicit _JAVA_OPTIONS found in assembly_conda.sh"
        echo "   Pilon may use default Java memory (potentially insufficient)"
        echo "   Consider adding: export _JAVA_OPTIONS=\"-Xmx32g\""
    fi
else
    echo "   ⚠️  assembly_conda.sh not found at expected location"
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""

WARNINGS=0
ERRORS=0

# Check conditions
if [[ $DEFAULT_MEMORY_GB -lt 8 ]]; then
    ((WARNINGS++))
fi

if [[ $OVERRIDE_TEST_GB -lt 30 ]]; then
    ((WARNINGS++))
fi

if command -v free &> /dev/null; then
    AVAIL_MEMORY=$(free -g | grep Mem | awk '{print $7}')
    if [[ $AVAIL_MEMORY -lt 32 ]]; then
        ((WARNINGS++))
    fi
    if [[ $AVAIL_MEMORY -lt 16 ]]; then
        ((ERRORS++))
    fi
fi

if ! grep -q "export _JAVA_OPTIONS" "$ASSEMBLY_SCRIPT" 2>/dev/null; then
    ((WARNINGS++))
fi

if [[ $ERRORS -gt 0 ]]; then
    echo "❌ ERRORS: $ERRORS"
    echo "   Pilon likely to fail. Action required."
    echo ""
elif [[ $WARNINGS -gt 0 ]]; then
    echo "⚠️  WARNINGS: $WARNINGS"
    echo "   Pilon may have issues. Review warnings above."
    echo ""
else
    echo "✅ All checks passed!"
    echo "   Pilon should work correctly with current configuration."
    echo ""
fi

echo "Recommendations:"
echo "  - Use assembly-based mode with ≥256 GB RAM"
echo "  - Monitor first job for memory issues"
echo "  - Check logs for 'OutOfMemoryError' messages"
echo ""
echo "For more information, see: fixes/PILON_MEMORY_FIX.md"
echo "=========================================="
