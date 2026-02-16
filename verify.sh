#!/bin/bash

for file in notes.html exam-skills-v2.html about.html contact.html refund.html; do
    echo ""
    echo "================= $file ================="
    
    # Count div tags
    open_divs=$(grep -o "<div" "$file" | wc -l)
    close_divs=$(grep -o "</div>" "$file" | wc -l)
    echo "DIV BALANCE: Opens=$open_divs, Closes=$close_divs"
    if [ "$open_divs" -eq "$close_divs" ]; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
    
    # Check for old element IDs in SCRIPT sections
    echo ""
    echo "OLD ELEMENT IDS (hamburgerBtn, mobileMenu, mobileOverlay):"
    if grep -A 200 "<script" "$file" | grep -E "(hamburgerBtn|mobileMenu|mobileOverlay)" > /dev/null 2>&1; then
        echo "  ✗ FAIL - Found old IDs"
        grep -A 200 "<script" "$file" | grep -E "(hamburgerBtn|mobileMenu|mobileOverlay)" | head -3
    else
        echo "  ✓ PASS"
    fi
    
    # Count duplicate IIFE blocks
    echo ""
    echo "DUPLICATE IIFE BLOCKS:"
    iife_count=$(grep -c "^(function()" "$file" 2>/dev/null || echo "0")
    echo "  Count: $iife_count"
    if [ "$iife_count" -le 1 ]; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
    
    # Check Supabase credentials
    echo ""
    echo "SUPABASE CREDENTIALS (zyaywzzmjpctpodpxhge):"
    if grep -q "zyaywzzmjpctpodpxhge" "$file" 2>/dev/null; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL - Missing Supabase URL"
    fi
    
    # Check for unicode dashes
    echo ""
    echo "UNICODE DASHES (em/en dash):"
    if grep -P "[–—]" "$file" > /dev/null 2>&1; then
        echo "  ✗ FAIL - Found unicode dashes"
        grep -P "[–—]" "$file" | head -2
    else
        echo "  ✓ PASS"
    fi
done
