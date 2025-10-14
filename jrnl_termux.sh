#!/usr/bin/env python3
"""
Simple jrnl replacement for Termux
Mimics basic jrnl functionality for note-taking
"""

import sys
import os
import re
from datetime import datetime, timedelta
import glob
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich.table import Table


def parse_time_string(time_str):
    """Parse time string like '3pm', '15:30', '3:45am' into hour, minute"""
    time_str = time_str.lower().strip()
    
    # Handle am/pm format
    am_pm_match = re.match(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', time_str)
    if am_pm_match:
        hour = int(am_pm_match.group(1))
        minute = int(am_pm_match.group(2)) if am_pm_match.group(2) else 0
        period = am_pm_match.group(3)
        
        if period == 'pm' and hour != 12:
            hour += 12
        elif period == 'am' and hour == 12:
            hour = 0
            
        return hour, minute
    
    # Handle 24-hour format
    hour_match = re.match(r'(\d{1,2})(?::(\d{2}))?', time_str)
    if hour_match:
        hour = int(hour_match.group(1))
        minute = int(hour_match.group(2)) if hour_match.group(2) else 0
        return hour, minute
    
    return None, None


def get_last_weekday(target_day):
    """Get the date of the last occurrence of target_day"""
    days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
    if target_day.lower() not in days:
        return None
    
    target_weekday = days.index(target_day.lower())
    today = datetime.now()
    current_weekday = today.weekday()
    
    # Calculate days back to last occurrence
    days_back = (current_weekday - target_weekday) % 7
    if days_back == 0:  # Today is the target day, get last week's
        days_back = 7
    
    target_date = today - timedelta(days=days_back)
    return target_date.replace(hour=0, minute=0, second=0, microsecond=0)


def parse_entry(entry_text):
    """Parse the jrnl entry to extract timestamp and content"""
    entry_text = entry_text.strip()
    
    # Look for the colon that separates timestamp from content
    colon_match = re.search(r':\s*(.*)$', entry_text)
    if not colon_match:
        # No colon found, use current time
        return datetime.now(), entry_text
    
    content = colon_match.group(1)
    timestamp_part = entry_text[:colon_match.start()].strip()
    
    # Remove "at" if present
    timestamp_part = re.sub(r'\bat\s+', '', timestamp_part, flags=re.IGNORECASE)
    
    # Parse the timestamp part
    now = datetime.now()
    target_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
    
    # Check for weekdays
    weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
    for day in weekdays:
        if day in timestamp_part.lower():
            target_date = get_last_weekday(day)
            timestamp_part = re.sub(day, '', timestamp_part, flags=re.IGNORECASE).strip()
            break
    
    # Check for special days
    if 'yesterday' in timestamp_part.lower():
        target_date = now.replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=1)
        timestamp_part = re.sub(r'yesterday', '', timestamp_part, flags=re.IGNORECASE).strip()
    elif 'today' in timestamp_part.lower():
        target_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
        timestamp_part = re.sub(r'today', '', timestamp_part, flags=re.IGNORECASE).strip()
    
    # Parse time if present
    if timestamp_part:
        hour, minute = parse_time_string(timestamp_part)
        if hour is not None and minute is not None:
            target_date = target_date.replace(hour=hour, minute=minute, second=0)
    
    return target_date, content


def ensure_directory_exists(filepath):
    """Create directory structure if it doesn't exist"""
    directory = os.path.dirname(filepath)
    if not os.path.exists(directory):
        os.makedirs(directory, exist_ok=True)


def write_entry(timestamp, content):
    """Write the entry to the appropriate file"""
    # Format: ~/shp/y/logs/timers/{year}/{month}/{day}.txt
    home = os.path.expanduser('~')
    year = timestamp.strftime('%Y')
    month = timestamp.strftime('%m')
    day = timestamp.strftime('%d')
    
    filepath = os.path.join(home, 'shp', 'y', 'logs', 'timers', year, month, f'{day}.txt')
    ensure_directory_exists(filepath)
    
    # Format the entry like jrnl
    formatted_timestamp = timestamp.strftime('[%Y-%m-%d %H:%M:%S]')
    entry_line = f'{formatted_timestamp} {content}\n'
    
    # Append to file
    with open(filepath, 'a', encoding='utf-8') as f:
        f.write(entry_line)
    
    print(f'Entry added to {filepath}')
    print(f'{formatted_timestamp} {content}')


def read_entries(limit=None, format_type='short', debug=False):
    """Read entries from journal files"""
    home = os.path.expanduser('~')
    base_path = os.path.join(home, 'shp', 'y', 'logs', 'timers')
    
    if not os.path.exists(base_path):
        print('No journal entries found.')
        return
    
    # Find all .txt files and sort by date
    pattern = os.path.join(base_path, '*', '*', '*.txt')
    files = glob.glob(pattern)
    files.sort(reverse=True)  # Most recent first
    
    entries = []
    for file_path in files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if not content:
                    continue
                    
                # Split by timestamp pattern to get individual entries
                # Look for pattern: [YYYY-MM-DD HH:MM:SS] at start of line
                parts = re.split(r'\n(?=\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\])', content)
                
                for part in parts:
                    part = part.strip()
                    if part and part.startswith('['):
                        # Clean up multi-line entries - join all lines into one
                        clean_entry = ' '.join(part.split())
                        entries.append(clean_entry)
                        
                if debug:
                    print(f"DEBUG: File {file_path}: found {len(parts)} entries")
                    
        except Exception as e:
            if debug:
                print(f"DEBUG: Error reading {file_path}: {e}")
            continue
    
    # Sort entries by timestamp (oldest first, like jrnl)
    entries.sort(key=lambda x: x[1:20])
    
    # Debug info
    if debug:
        print(f"DEBUG: Total entries found: {len(entries)}")
        if entries:
            print(f"DEBUG: Oldest entry: {entries[0][:20]}")
            print(f"DEBUG: Newest entry: {entries[-1][:20]}")
    
    # Apply limit if specified
    if limit:
        entries = entries[-limit:] if len(entries) > limit else entries
    
    if not entries:
        print('No entries found.')
        return
    
    # Debug: Show how many entries we're about to display
    if debug:
        print(f"DEBUG: About to display {len(entries)} entries in {format_type} format")
    
    if format_type == 'fancy':
        print_fancy_format(entries, debug)
    else:
        print_short_format(entries, debug)


def print_short_format(entries, debug=False):
    """Print entries in simple format (just titles/brief content)"""
    if debug:
        print(f"DEBUG: About to display {len(entries)} entries")
    
    for entry in entries:  # Show oldest first (already sorted)
        # Extract just the title part (before first dot) for short format
        timestamp_match = re.match(r'\[(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})\] (.+)', entry)
        if timestamp_match:
            content = timestamp_match.group(3)
            # Get text before first dot for "short" format
            title = content.split('.')[0] + '.' if '.' in content else content
            print(f"[{timestamp_match.group(1)} {timestamp_match.group(2)}] {title}")
        else:
            print(entry)


def print_fancy_format(entries, debug=False):
    """Print entries in fancy format using Rich"""
    if not entries:
        return
    
    console = Console()
    
    if debug:
        print(f"DEBUG: Processing {len(entries)} entries in fancy format")
    
    displayed_count = 0
    skipped_count = 0
    
    for entry in entries:
        # Parse the entry - handle both with and without AM/PM
        timestamp_match = re.match(r'\[(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})(?:\s*(AM|PM))?\] (.+)', entry)
        if not timestamp_match:
            skipped_count += 1
            if debug:
                print(f"DEBUG: Skipped entry (no match): {entry[:50]}...")
            continue
        
        date_str = timestamp_match.group(1)
        time_str = timestamp_match.group(2)
        am_pm = timestamp_match.group(3) if timestamp_match.group(3) else ""
        content = timestamp_match.group(4)
        
        # Split content into title and body
        if '.' in content:
            parts = content.split('.', 1)
            title = parts[0] + '.'
            body = parts[1].strip() if len(parts) > 1 and parts[1].strip() else None
        else:
            title = content
            body = None
        
        # Create Rich text objects with styling
        timestamp_full = f"{date_str} {time_str}"
        if am_pm:
            timestamp_full += f" {am_pm}"
        
        # Create the title with timestamp
        title_text = Text()
        title_text.append(title, style="bold blue")
        
        # Create the panel content
        if body:
            panel_content = Text()
            panel_content.append(body, style="white")
        else:
            panel_content = Text("")
        
        # Create and print the panel
        panel = Panel(
            panel_content,
            title=title_text,
            title_align="left",
            subtitle=Text(timestamp_full, style="dim cyan"),
            subtitle_align="right",
            border_style="bright_blue",
            padding=(0, 1)
        )
        
        console.print(panel)
        displayed_count += 1
    
    if debug:
        print(f"DEBUG: Displayed {displayed_count} entries, skipped {skipped_count} entries")


def main():
    if len(sys.argv) < 2:
        print('Usage: jrnl "your entry text" OR jrnl [options]')
        print()
        print('Options:')
        print('  --short [n]        Show last n entries (default: 10)')
        print('  --format fancy     Show entries in fancy format')
        print('  --debug            Show debug information')
        print()
        print('Examples:')
        print('  jrnl "Work. Had a productive day"')
        print('  jrnl "yesterday 3pm: Met with client"')
        print('  jrnl "monday at 9am: Started new project"')
        print('  jrnl --short 5')
        print('  jrnl --format fancy')
        print('  jrnl --format fancy --debug')
        sys.exit(1)
    
    # Check for debug flag
    debug = '--debug' in sys.argv
    if debug:
        # Remove --debug from args list
        sys.argv.remove('--debug')
    
    # Now process remaining arguments
    args = sys.argv[1:]
    
    # Check for show commands
    if len(args) > 0 and args[0] == '--short':
        limit = 10  # default
        if len(args) > 1 and args[1].isdigit():
            limit = int(args[1])
        read_entries(limit=limit, format_type='short', debug=debug)
        return
    
    elif len(args) >= 2 and args[0] == '--format' and args[1] == 'fancy':
        read_entries(format_type='fancy', debug=debug)
        return
    
    # Otherwise, treat as entry text
    entry_text = ' '.join(args)
    
    try:
        timestamp, content = parse_entry(entry_text)
        if not content.strip():
            print('Error: Entry content cannot be empty')
            sys.exit(1)
        
        if debug:
            print(f"DEBUG: Parsed timestamp: {timestamp}")
            print(f"DEBUG: Parsed content: {content}")
        
        write_entry(timestamp, content)
    
    except Exception as e:
        print(f'Error: {e}')
        sys.exit(1)


if __name__ == '__main__':
    main()
