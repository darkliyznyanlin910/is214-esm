from locust import HttpUser, task, between, events
import time
from statistics import mean
import threading
from datetime import datetime
import json


class Stats:
    def __init__(self):
        self.request_count = 0
        self.failures = 0
        self.latencies = []
        self.window_size = 50
        self._lock = threading.Lock()
        self.percentiles = {}
        self.min_response = float('inf')
        self.max_response = 0

    def add_request(self, success, latency):
        with self._lock:
            self.request_count += 1
            if not success:
                self.failures += 1
            self.latencies.append(latency)
            self.min_response = min(self.min_response, latency)
            self.max_response = max(self.max_response, latency)
            if len(self.latencies) > self.window_size:
                self.latencies.pop(0)

    def get_stats(self):
        with self._lock:
            failure_rate = (self.failures / self.request_count *
                            100) if self.request_count > 0 else 0
            avg_latency = mean(self.latencies) if self.latencies else 0
            return self.request_count, failure_rate, avg_latency


stats = Stats()


def print_stats():
    while True:
        reqs, fail_rate, avg_lat = stats.get_stats()
        print(
            f"Requests: {reqs} | Failure Rate: {fail_rate:.2f}% | Avg Latency: {avg_lat:.2f}ms")
        time.sleep(5)


# Start stats printer in background
threading.Thread(target=print_stats, daemon=True).start()


class ESMOSLoadTest(HttpUser):
    host = "https://esmk.johnnyknl.com"
    wait_time = between(1, 3)

    @task(4)
    def test_shop_page(self):
        start_time = time.time()
        response = self.client.get("/shop")
        latency = (time.time() - start_time) * 1000  # Convert to ms
        stats.add_request(response.ok, latency)
    
    @task(2)
    def test_home_page(self):
        start_time = time.time()
        response = self.client.get("/")
        latency = (time.time() - start_time) * 1000
        stats.add_request(response.ok, latency)
    
    @task(1)
    def test_services_page(self):
        start_time = time.time()
        response = self.client.get("/services")
        latency = (time.time() - start_time) * 1000
        stats.add_request(response.ok, latency)
    
    @task(1)
    def test_contact_page(self):
        start_time = time.time()
        response = self.client.get("/contact-us")
        latency = (time.time() - start_time) * 1000
        stats.add_request(response.ok, latency)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Generate markdown report when the test stops"""
    stats_history = environment.stats.history
    if not stats_history:
        return

    # Calculate aggregate stats
    total_reqs = environment.stats.total.num_requests
    total_fails = environment.stats.total.num_failures
    avg_response = environment.stats.total.avg_response_time
    requests_per_sec = environment.stats.total.current_rps

    # Get error stats
    error_dict = {}
    for name, error in environment.stats.errors.items():
        error_dict[str(name)] = {
            'occurrences': error.occurrences,
            'error': str(error.error),
            'method': error.method,
            'name': error.name
        }

    # Get percentiles - using get_current_response_time_percentile instead
    percentiles = {
        0.5: environment.stats.total.get_current_response_time_percentile(0.5),
        0.66: environment.stats.total.get_current_response_time_percentile(0.66),
        0.75: environment.stats.total.get_current_response_time_percentile(0.75),
        0.80: environment.stats.total.get_current_response_time_percentile(0.80),
        0.90: environment.stats.total.get_current_response_time_percentile(0.90),
        0.95: environment.stats.total.get_current_response_time_percentile(0.95),
        0.98: environment.stats.total.get_current_response_time_percentile(0.98),
        0.99: environment.stats.total.get_current_response_time_percentile(0.99),
        0.999: environment.stats.total.get_current_response_time_percentile(0.999),
        0.9999: environment.stats.total.get_current_response_time_percentile(0.9999)
    }

    # Create error report section
    error_report = "\n## Error Report\n"
    if error_dict:
        error_report += "| Method | Endpoint | Occurrences | Error |\n|--------|-----------|-------------|-------|\n"
        for _, error in error_dict.items():
            error_report += f"| {error['method']} | {error['name']} | {error['occurrences']} | {error['error']} |\n"
    else:
        error_report += "No errors occurred during the test.\n"

    report = f"""# Load Test Report
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Summary
- Total Requests: {total_reqs:,}
- Failure Rate: {(total_fails/total_reqs*100 if total_reqs > 0 else 0):.2f}%
- Average Response Time: {avg_response:.0f}ms
- Requests/sec: {requests_per_sec:.2f}

## Response Time Breakdown
| Metric | Value (ms) |
|--------|------------|
| Min    | {environment.stats.total.min_response_time:.0f} |
| Max    | {environment.stats.total.max_response_time:.0f} |
| Median | {percentiles[0.5]:.0f} |

## Percentiles
| Percentile | Response Time (ms) |
|------------|-------------------|
| 50%        | {percentiles[0.5]:.0f} |
| 66%        | {percentiles[0.66]:.0f} |
| 75%        | {percentiles[0.75]:.0f} |
| 80%        | {percentiles[0.80]:.0f} |
| 90%        | {percentiles[0.90]:.0f} |
| 95%        | {percentiles[0.95]:.0f} |
| 98%        | {percentiles[0.98]:.0f} |
| 99%        | {percentiles[0.99]:.0f} |
| 99.9%      | {percentiles[0.999]:.0f} |
| 99.99%     | {percentiles[0.9999]:.0f} |
| 100%       | {environment.stats.total.max_response_time:.0f} |
{error_report}"""

    with open('REPORT.md', 'w') as f:
        f.write(report)

    # Also save raw data for further analysis if needed
    raw_data = {
        'timestamp': datetime.now().isoformat(),
        'total_requests': total_reqs,
        'total_failures': total_fails,
        'avg_response_time': avg_response,
        'requests_per_sec': requests_per_sec,
        'percentiles': percentiles,
        'min_response': environment.stats.total.min_response_time,
        'max_response': environment.stats.total.max_response_time,
        'errors': error_dict
    }

    with open('report_data.json', 'w') as f:
        json.dump(raw_data, f, indent=2)
