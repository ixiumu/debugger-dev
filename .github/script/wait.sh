#!/bin/bash

# Set script timeout (minutes)
timeout=1

# Convert timeout to seconds
timeout_seconds=$((timeout * 60))

# Get current timestamp
start_time=$(date +%s)

# Loop to check user connection status
while true; do
  # Get the current number of active SSH user connections
  #current_user_count=$(who | grep -c "pts/")
  current_user_count=$(ps x | grep sshd | grep -c @)
  
  echo "Active user connections: ${current_user_count}"

  if [ $current_user_count -gt 0 ]; then
    # Users are connected
    start_time=$(date +%s)
  else
    # Calculate connection duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if [ $duration -ge $timeout_seconds ]; then
      # Connection duration exceeds the set timeout, exit the script
      echo "All users have disconnected for more than ${timeout} minutes. "
      break
    fi
  fi

  # Wait for 1 minute (60 seconds) and check user connection status again
  sleep 60
done
