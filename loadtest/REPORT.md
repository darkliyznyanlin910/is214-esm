# Load Test Report
Generated: 2025-03-22 12:09:27

## Summary
- Total Requests: 680
- Failure Rate: 100.00%
- Average Response Time: 1456ms
- Requests/sec: 43.17

## Response Time Breakdown
| Metric | Value (ms) |
|--------|------------|
| Min    | 14 |
| Max    | 4773 |
| Median | 590 |

## Percentiles
| Percentile | Response Time (ms) |
|------------|-------------------|
| 50%        | 590 |
| 66%        | 880 |
| 75%        | 3600 |
| 80%        | 3700 |
| 90%        | 3900 |
| 95%        | 4000 |
| 98%        | 4100 |
| 99%        | 4100 |
| 99.9%      | 4800 |
| 99.99%     | 4800 |
| 100%       | 4773 |

## Error Report
| Method | Endpoint | Occurrences | Error |
|--------|-----------|-------------|-------|
| GET | /shop | 236 | 502 Server Error: Bad Gateway for url: /shop |
| GET | /services | 57 | 502 Server Error: Bad Gateway for url: /services |
| GET | / | 131 | 502 Server Error: Bad Gateway for url: / |
| GET | /contact-us | 61 | 502 Server Error: Bad Gateway for url: /contact-us |
| GET | /shop | 100 | 500 Server Error: INTERNAL SERVER ERROR for url: /shop |
| GET | / | 48 | 500 Server Error: INTERNAL SERVER ERROR for url: / |
| GET | /services | 26 | 500 Server Error: INTERNAL SERVER ERROR for url: /services |
| GET | /contact-us | 21 | 500 Server Error: INTERNAL SERVER ERROR for url: /contact-us |
