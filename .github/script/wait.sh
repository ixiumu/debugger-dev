#!/bin/bash

# Convert timeout to seconds
timeout_seconds=$((2 * 60))

# Get current timestamp
start_time=$(date +%s)

# Initialize user connection count
user_count=0

# Loop to check user connection status
while true; do
  # Get the current number of active SSH user connections
  current_user_count=$(who | grep -c "pts/")

  echo $current_user_count
  echo $start_time

  if [ $current_user_count -gt 0 ]; then
    # Users are connected
    if [ $user_count -eq 0 ]; then
      # Update user connection count and start timestamp
      user_count=$current_user_count
      start_time=$(date +%s)
    fi
  else
    # No users are connected
    if [ $user_count -gt 0 ]; then
      # Update user connection count and end timestamp
      user_count=0
      end_time=$(date +%s)

      # Calculate connection duration
      duration=$((end_time - start_time))

      if [ $duration -ge $timeout_seconds ]; then
        # Connection duration exceeds the set timeout, exit the script
        break
      fi
    fi
  fi

  # Wait for 1 minute (60 seconds) and check user connection status again
  sleep 60
done

echo "All users have disconnected for more than 30 minutes. Exiting the script."