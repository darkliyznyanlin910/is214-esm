#!/bin/bash

URL="https://odoo.test.com" # CHANGE
CONCURRENT_USERS=500
REPORT_FILE="load_test_report.md"
JSON_REPORT="load_test_data.json"

echo "Starting load test with $CONCURRENT_USERS concurrent users to $URL"
echo "Press Ctrl+C to stop the test"

# Create temp directory for results
TEMP_DIR=$(mktemp -d)
echo "Storing temporary results in $TEMP_DIR"

# Function to make a single request
make_request() {
  local id=$1
  # Add small random delay to avoid overwhelming the server
  sleep $(echo "scale=3; $RANDOM/32768" | bc)
  local result=$(curl -s -o /dev/null -w "%{http_code},%{time_total},%{time_connect},%{time_starttransfer}" "$URL")
  echo "$result" > "$TEMP_DIR/result_$id"
}

# Start timestamp
START_TIME=$(date +%s.%N)

# Run the concurrent requests
for i in $(seq 1 $CONCURRENT_USERS); do
  make_request $i &
  # Add slight delay between starting requests
  sleep 0.05
done

# Wait for all background processes to complete
wait

# End timestamp
END_TIME=$(date +%s.%N)
DURATION=$(echo "$END_TIME - $START_TIME" | bc)

# Process results
TOTAL_REQUESTS=$CONCURRENT_USERS
SUCCESS_COUNT=0
FAILURE_COUNT=0
TOTAL_TIME=0
MIN_TIME=999999
MAX_TIME=0
declare -a RESPONSE_TIMES

echo "Processing results..."

for i in $(seq 1 $CONCURRENT_USERS); do
  if [ -f "$TEMP_DIR/result_$i" ]; then
    RESULT=$(cat "$TEMP_DIR/result_$i")
    STATUS_CODE=$(echo $RESULT | cut -d',' -f1)
    RESPONSE_TIME=$(echo $RESULT | cut -d',' -f2)
    CONNECT_TIME=$(echo $RESULT | cut -d',' -f3)
    TTFB=$(echo $RESULT | cut -d',' -f4)
    
    # Convert to milliseconds for consistency with Python version
    RESPONSE_TIME_MS=$(echo "$RESPONSE_TIME * 1000" | bc)
    
    # Store for percentile calculation
    RESPONSE_TIMES+=($RESPONSE_TIME_MS)
    
    # Update min/max
    if (( $(echo "$RESPONSE_TIME_MS < $MIN_TIME" | bc -l) )); then
      MIN_TIME=$RESPONSE_TIME_MS
    fi
    
    if (( $(echo "$RESPONSE_TIME_MS > $MAX_TIME" | bc -l) )); then
      MAX_TIME=$RESPONSE_TIME_MS
    fi
    
    # Sum for average calculation
    TOTAL_TIME=$(echo "$TOTAL_TIME + $RESPONSE_TIME_MS" | bc)
    
    # Count successes/failures
    if [[ $STATUS_CODE -ge 200 && $STATUS_CODE -lt 400 ]]; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
    
    # Save detailed results for JSON
    echo "{\"id\": $i, \"status\": $STATUS_CODE, \"response_time\": $RESPONSE_TIME_MS, \"connect_time\": $(echo "$CONNECT_TIME * 1000" | bc), \"ttfb\": $(echo "$TTFB * 1000" | bc)}" >> "$TEMP_DIR/details.json"
  fi
done

# Calculate stats
AVG_RESPONSE_TIME=$(echo "scale=2; $TOTAL_TIME / $TOTAL_REQUESTS" | bc)
FAILURE_RATE=$(echo "scale=2; ($FAILURE_COUNT / $TOTAL_REQUESTS) * 100" | bc)
REQUESTS_PER_SEC=$(echo "scale=2; $TOTAL_REQUESTS / $DURATION" | bc)

# Sort response times for percentiles
IFS=$'\n' SORTED_TIMES=($(sort -n <<<"${RESPONSE_TIMES[*]}"))
unset IFS

# Calculate percentiles
get_percentile() {
  local p=$1
  local idx=$(echo "($p * ${#SORTED_TIMES[@]} / 100) - 1" | bc)
  idx=${idx%.*} # truncate to integer
  if (( idx < 0 )); then idx=0; fi
  echo "${SORTED_TIMES[$idx]}"
}

P50=$(get_percentile 50)
P75=$(get_percentile 75)
P90=$(get_percentile 90)
P95=$(get_percentile 95)
P99=$(get_percentile 99)

# Generate markdown report
cat > "$REPORT_FILE" << EOF
# Load Test Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')

## Summary
- URL: $URL
- Concurrent Users: $CONCURRENT_USERS
- Total Requests: $TOTAL_REQUESTS
- Failure Rate: ${FAILURE_RATE}%
- Average Response Time: ${AVG_RESPONSE_TIME}ms
- Requests/sec: ${REQUESTS_PER_SEC}
- Test Duration: ${DURATION}s

## Response Time Breakdown
| Metric | Value (ms) |
|--------|------------|
| Min    | ${MIN_TIME} |
| Max    | ${MAX_TIME} |
| Median | ${P50} |

## Percentiles
| Percentile | Response Time (ms) |
|------------|-------------------|
| 50%        | ${P50} |
| 75%        | ${P75} |
| 90%        | ${P90} |
| 95%        | ${P95} |
| 99%        | ${P99} |
| 100%       | ${MAX_TIME} |

## Status Codes
- Successful responses (2xx/3xx): $SUCCESS_COUNT
- Failed responses (4xx/5xx): $FAILURE_COUNT
EOF

# Generate JSON report
echo "{" > "$JSON_REPORT"
echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$JSON_REPORT"
echo "  \"url\": \"$URL\"," >> "$JSON_REPORT"
echo "  \"concurrent_users\": $CONCURRENT_USERS," >> "$JSON_REPORT"
echo "  \"total_requests\": $TOTAL_REQUESTS," >> "$JSON_REPORT"
echo "  \"successful_requests\": $SUCCESS_COUNT," >> "$JSON_REPORT"
echo "  \"failed_requests\": $FAILURE_COUNT," >> "$JSON_REPORT"
echo "  \"failure_rate\": $FAILURE_RATE," >> "$JSON_REPORT"
echo "  \"avg_response_time\": $AVG_RESPONSE_TIME," >> "$JSON_REPORT"
echo "  \"min_response_time\": $MIN_TIME," >> "$JSON_REPORT"
echo "  \"max_response_time\": $MAX_TIME," >> "$JSON_REPORT"
echo "  \"p50\": $P50," >> "$JSON_REPORT"
echo "  \"p75\": $P75," >> "$JSON_REPORT"
echo "  \"p90\": $P90," >> "$JSON_REPORT"
echo "  \"p95\": $P95," >> "$JSON_REPORT"
echo "  \"p99\": $P99," >> "$JSON_REPORT"
echo "  \"requests_per_second\": $REQUESTS_PER_SEC," >> "$JSON_REPORT"
echo "  \"duration\": $DURATION," >> "$JSON_REPORT"
echo "  \"details\": [" >> "$JSON_REPORT"
cat "$TEMP_DIR/details.json" | sed '$ ! s/$/,/' >> "$JSON_REPORT"
echo "  ]" >> "$JSON_REPORT"
echo "}" >> "$JSON_REPORT"

# Clean up temp files
rm -rf "$TEMP_DIR"

echo "Load test completed"
echo "Report generated: $REPORT_FILE"
echo "JSON data saved: $JSON_REPORT"
