# F5 BigIP Patching Automation

**Reducing monthly maintenance overhead from 50 minutes to under 1 minute**

## The Problem

In a major telecommunications infrastructure environment, monthly patching windows required manual manipulation of 30+ F5 BigIP LTM nodes across four separate partitions (BE-PRO, BE-OMT, FE-DMZ, FE-DMZ-ext). 

**The manual process:**
- **22:00**: Disable nodes (50 minutes of tmsh commands)
- **22:00-02:00**: Patching window
- **02:00**: Re-enable nodes (another 50 minutes)

This meant operations engineers spent **1 hour 40 minutes per month** clicking repetitive, error-prone GUI buttons during off-hours. One click could impact service availability.

## The Solution

Automated the entire node management workflow with a bash script leveraging F5's tmsh CLI. The script handles all three patching scenarios (T71, T72, T73) with:
- Interactive menu-driven interface
- Bulk enable/disable operations
- Node status verification
- Multi-partition support

**Time reduction: 50 minutes → under 60 seconds**

## Real-World Impact

### Operational Benefits

- **Time savings**: ~20 hours annually per operations team
- **Error reduction**: Eliminated manual typing errors during critical windows
- **Consistency**: Standardized process across all patching scenarios
- **Reliability**: Repeatable, testable workflow
- **Knowledge transfer**: Simple enough for non-experts to execute

## Technical Details

### Architecture

The script manages F5 nodes across multiple partitions using tmsh (Traffic Management Shell):

```
F5_BE-PRO       → Backend Production nodes
F5_BE-OMT       → Backend OMT nodes  
F5_FE-DMZ       → Frontend DMZ nodes
F5_FE-DMZ-ext   → External DMZ nodes
```

### Supported Operations

- **List**: Display current node session states
- **Disable**: Set nodes to `user-disabled` (graceful drain)
- **Enable**: Set nodes to `user-enabled` (return to service)

### Patching Scenarios

Three distinct patching scenarios (T71, T72, T73) with different node groupings:
- Each scenario targets specific nodes based on infrastructure topology
- Supports validation before and after patching
- Handles routing group percentages for multi-homed nodes

## Usage

### Prerequisites

- F5 BigIP with tmsh CLI access
- Bash shell environment
- Appropriate permissions for node modification

### Running the Script

```bash
chmod +x f5-patching-automation.sh
./f5-patching-automation.sh
```

### Interactive Workflow

```
Which patching scenario? [1/2/3/Q to quit] >> 1
Action: [L]ist / [D]isable / [E]enable / [Q]uit >> l
=== Processing T71 Patching Scenario ===
[Node status output]

Action: [L]ist / [D]isable / [E]enable / [Q]uit >> d
=== Processing T71 Patching Scenario ===
[Nodes disabled]

Action: [L]ist / [D]isable / [E]enable / [Q]uit >> q
```

## Code Highlights

### Clean Abstraction

Each patching scenario has a dedicated function:
```bash
t71-switcher()  # Handles T71 patching scenario
t72-switcher()  # Handles T72 patching scenario  
t73-switcher()  # Handles T73 patching scenario
```

### Error Prevention

- Input validation for scenario and action selection
- Consistent command structure reduces typos
- Dry-run capability (list before modify)

### Maintainability

- Clear variable naming (`f5BePro`, `f5BeOmt`, etc.)
- Comprehensive comments and documentation
- Version history tracking

## Lessons Learned

### What Worked

1. **Simple is better**: Bash was the right tool for this job—no need for complex frameworks
2. **User-friendly CLI**: Operations team adopted it immediately because it was intuitive
3. **Incremental development**: Started with one scenario, expanded to three
4. **Real-world testing**: The "bar deployment" proved the interface was truly simple

### Evolution

- **v0.1.0**: Initial single-scenario implementation
- **v0.1.1**: Added for loops to reduce code repetition
- **v1.3**: Expanded to all three patching scenarios
- **v1.4**: Production-ready with full error handling

## Future Enhancements

Potential improvements for extended functionality:

- [ ] Add pre-flight checks (verify node counts before disabling)
- [ ] Implement rollback on partial failures
- [ ] Generate execution logs for audit trail
- [ ] Add support for scheduled automation (cron integration)
- [ ] Create web UI for non-CLI users
- [ ] Extend to additional F5 partitions as infrastructure grows

## License

MIT License - Feel free to adapt for your own F5 automation needs

## Author

**Gabriele Saronni**  
Network Engineer & Automation Enthusiast  
[LinkedIn](https://linkedin.com/in/gabriele-s-54514173) | [GitHub](https://github.com/gsaronni)
