#!/bin/bash

################################################################################
# F5 BigIP Patching Automation Script
# 
# Purpose: Automate bulk enable/disable of F5 LTM nodes during maintenance windows
# Author: Gabriele Saronni
# Created: 2022-07-26
# 
# Reduces patching preparation time from 50 minutes to under 1 minute by
# automating repetitive tmsh commands across multiple F5 partitions.
#
# Usage: ./f5-patching-automation.sh
#        Follow interactive prompts to select patching scenario and action
################################################################################

# Version History
# v0.1.0 - 2022-07-26: Initial creation
# v0.1.1 - 2022-07-28: Added for loops to reduce code repetition
# v0.1.2 - 2022-07-28: Refactored list and disable command logic
# v1.3   - 2022-08-01: Added support for all three patching scenarios
# v1.4   - 2022-08-01: Completed all T71, T72, T73 patching workflows

################################################################################
# Function: t71-switcher
# Description: Handles T71 patching scenario nodes across all F5 partitions
# Parameters: Uses global $answer variable for action selection
################################################################################
t71-switcher() {
  echo "=== Processing T71 Patching Scenario ==="
  
  # Determine action: enable or disable
  local jiggle=""
  if [[ "$answer" == *"e"* ]]; then
    jiggle="enabled"
  elif [[ "$answer" == *"d"* ]]; then
    jiggle="disabled"
  fi
  
  # F5_BE-PRO Partition - Backend Production Nodes
  local f5BePro=("oss231" "oss245" "oss237bepro")
  for node in "${f5BePro[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-PRO; list /ltm node $node" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-PRO; modify /ltm node $node session user-$jiggle"
    fi
  done
  
  # F5_BE-OMT Partition - Backend OMT Nodes
  local f5BeOmt=("10.129.173.142%3" "10.129.173.162%3" "oss261v" "10.129.173.149%3" "oss231" "oss245" "oss234v" "10.129.173.51%3" "10.129.173.148%3")
  for node in "${f5BeOmt[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-OMT; list /ltm node $node" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-OMT; modify /ltm node $node session user-$jiggle"
    fi
  done
  
  # F5_FE-DMZ Partition - Frontend DMZ Node
  if [[ "$answer" == *"l"* ]]; then
    tmsh -c "cd /F5_FE-DMZ/; list /ltm node 10.129.164.78%4" | grep -E 'node|session'
  else
    tmsh -c "cd /F5_FE-DMZ/; modify /ltm node 10.129.164.78%4 session user-$jiggle"
  fi
  
  # F5_FE-DMZ-ext Partition - External DMZ Nodes
  local f5FeDmzExt=("oss231" "oss245" "10.129.164.99%5")
  for node in "${f5FeDmzExt[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_FE-DMZ-ext; list /ltm node $node" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_FE-DMZ-ext; modify /ltm node $node session user-$jiggle"
    fi
  done
}

################################################################################
# Function: t72-switcher
# Description: Handles T72 patching scenario nodes across all F5 partitions
# Parameters: Uses global $answer variable for action selection
################################################################################
t72-switcher() {
  echo "=== Processing T72 Patching Scenario ==="
  
  # Determine action: enable or disable
  local jiggle=""
  if [[ "$answer" == *"e"* ]]; then
    jiggle="enabled"
  elif [[ "$answer" == *"d"* ]]; then
    jiggle="disabled"
  fi
  
  # F5_FE-DMZ Partition - Frontend DMZ Node
  if [[ "$answer" == *"l"* ]]; then
    tmsh -c "cd /F5_FE-DMZ/; list /ltm node 10.129.164.79%4" | grep -E 'node|session'
  else
    tmsh -c "cd /F5_FE-DMZ/; modify /ltm node 10.129.164.79%4 session user-$jiggle"
  fi
  
  # F5_BE-PRO Partition - Backend Production Nodes
  local f5BePro2=("10.129.175.76%2" "oss134v" "oss232")
  for node in "${f5BePro2[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-PRO; list /ltm node $node" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-PRO; modify /ltm node $node session user-$jiggle"
    fi
  done
  
  # F5_BE-OMT Partition - Backend OMT Nodes
  local f5BeOmt2=("10.129.173.52%3" "oss246" "10.129.173.130%3" "oss243" "oss235v" "10.129.173.133%3" "10.129.173.144%3" "oss262v")
  for node in "${f5BeOmt2[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-OMT; list /ltm node $node" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-OMT; modify /ltm node $node session user-$jiggle"
    fi
  done
  
  # F5_FE-DMZ-ext Partition - External DMZ Nodes
  local f5FeDmzExt2=("oss232" "oss246" "10.129.164.110%5" "oss232")
  for node in "${f5FeDmzExt2[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_FE-DMZ-ext; list /ltm node $node" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_FE-DMZ-ext; modify /ltm node $node session user-$jiggle"
    fi
  done
}

################################################################################
# Function: t73-switcher
# Description: Handles T73 patching scenario nodes across all F5 partitions
# Parameters: Uses global $answer variable for action selection
################################################################################
t73-switcher() {
  echo "=== Processing T73 Patching Scenario ==="
  
  # Determine action: enable or disable
  local jiggle=""
  if [[ "$answer" == *"e"* ]]; then
    jiggle="enabled"
  elif [[ "$answer" == *"d"* ]]; then
    jiggle="disabled"
  fi
  
  # F5_FE-DMZ Partition - Frontend DMZ Node
  if [[ "$answer" == *"l"* ]]; then
    tmsh -c "cd /F5_FE-DMZ/; list /ltm node 10.129.164.80%4" | grep -E 'node|session'
  else
    tmsh -c "cd /F5_FE-DMZ/; modify /ltm node 10.129.164.80%4 session user-$jiggle"
  fi
  
  # F5_BE-PRO Partition - Backend Production Nodes
  local f5BePro3=("oss233" "oss205v" "10.129.175.77%2")
  for node in "${f5BePro3[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-PRO; list /ltm node $node" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-PRO; modify /ltm node $node session user-$jiggle"
    fi
  done
  
  # F5_BE-OMT Partition - Backend OMT Nodes
  local f5BeOmt3=("oss233" "oss236v" "10.129.173.204%3" "10.129.173.134%3" "10.129.173.151%3" "10.129.173.153%3" "10.129.173.163%3" "oss263v")
  for node in "${f5BeOmt3[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_BE-OMT; list /ltm node $node" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_BE-OMT; modify /ltm node $node session user-$jiggle"
    fi
  done
  
  # F5_FE-DMZ-ext Partition - External DMZ Nodes
  local f5FeDmzExt3=("oss233" "oss247")
  for node in "${f5FeDmzExt3[@]}"; do
    if [[ "$answer" == *"l"* ]]; then
      tmsh -c "cd /F5_FE-DMZ-ext; list /ltm node $node" | grep -E 'node|session'
    else
      tmsh -c "cd /F5_FE-DMZ-ext; modify /ltm node $node session user-$jiggle"
    fi
  done
}

################################################################################
# Function: main
# Description: Interactive CLI loop for patching scenario and action selection
################################################################################
main() {
  while true; do
    echo ""
    read -p "Which patching scenario? [1/2/3/Q to quit] >> " pick
    case $pick in
      1|2|3)
        while true; do
          echo ""
          read -p "Action: [L]ist / [D]isable / [E]enable / [Q]uit >> " answer
          case $answer in
            [edlEDL]*)
              # Convert to lowercase for consistency
              answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
              t7$pick-switcher
              ;;
            [Qq]*)
              break
              ;;
            *)
              echo "Invalid input. Please choose L, D, E, or Q"
              ;;
          esac
        done
        ;;
      [Qq]*)
        echo "Patching automation complete. Goodbye!"
        break
        ;;
      *)
        echo "Invalid scenario. Please choose 1, 2, 3, or Q"
        ;;
    esac
  done
}

################################################################################
# Script Entry Point
################################################################################
echo "=========================================="
echo "F5 BigIP Patching Automation"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""
main
