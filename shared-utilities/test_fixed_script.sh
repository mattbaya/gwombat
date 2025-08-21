#!/bin/bash
# Test script to check if the fixes work

# Test the main script with input
echo "Testing main script with exit command..."
echo "x" | bash gwombat.sh 2>&1 | grep -E "(GWOMBAT|Select an option|Goodbye)" | tail -3