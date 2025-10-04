# F5 BigIP Patching Automation

## Problem
Managing 30+ F5 nodes across multiple partitions during patching windows 
required 50+ minutes of manual tmsh commands with high risk of typos.

## Solution
Bash automation script reducing patching preparation from 50min to 5min.

## Features
- Bulk enable/disable of F5 nodes
- Support for multiple patching scenarios
- Interactive CLI for operations team
- Error prevention through standardized commands

## Technical Details
- F5 tmsh command automation
- Multi-partition support (BE-PRO, BE-OMT, FE-DMZ, FE-DMZ-ext)
- Session state management
