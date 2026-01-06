# Check Temporal Workflow Status

Check the status of a Temporal workflow: $ARGUMENTS

## Usage

Invoke this command with a workflow ID to check its current status.

## What This Command Does

1. Queries the workflow status using Temporal CLI
2. Extracts key information: status, current step, errors
3. Returns a concise status summary

## Commands Executed

```bash
temporal workflow show -w "$ARGUMENTS"
temporal workflow show -w "$ARGUMENTS" | grep -i "status\|error\|state"
```

## Expected Output

- **Status**: Running, Completed, Failed, Canceled, Terminated
- **Current Step**: The workflow's current activity or state
- **Last Error**: Most recent error if the workflow is failing
- **Recommendation**: Suggested action if issues are detected
