
import os
import time
import re
import requests
from collections import deque

LOG_PATH = "/logs/access.log"
WINDOW_SIZE = int(os.getenv("WINDOW_SIZE", 200))
ERROR_THRESHOLD = float(os.getenv("ERROR_RATE_THRESHOLD", 2))
COOLDOWN = int(os.getenv("ALERT_COOLDOWN_SEC", 300))
SLACK_URL = os.getenv("SLACK_WEBHOOK_URL")
MAINTENANCE = os.getenv("MAINTENANCE_MODE", "false").lower() == "true"

error_window = deque(maxlen=WINDOW_SIZE)
last_pool = os.getenv("ACTIVE_POOL")
last_alert_time = 0

def post_to_slack(message):
    global last_alert_time
    if MAINTENANCE or time.time() - last_alert_time < COOLDOWN:
        return
    try:
        requests.post(SLACK_URL, json={"text": message})
        last_alert_time = time.time()
    except Exception as e:
        print(f"Slack alert failed: {e}")

def parse_line(line):
    pool_match = re.search(r'pool="([^"]+)"', line)
    status_match = re.search(r'upstream_status="([^"]+)"', line)
    pool = pool_match.group(1) if pool_match else None
    status = status_match.group(1) if status_match else None
    return pool, status

def monitor_logs():
    global last_pool
    with open(LOG_PATH, "r") as f:
        f.seek(0, 2)
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.5)
                continue
            pool, status = parse_line(line)
            if pool and pool != last_pool:
                post_to_slack(f"⚠️ Failover detected: {last_pool} → {pool}")
                last_pool = pool
            if status and status.startswith("5"):
                error_window.append(1)
            else:
                error_window.append(0)
            if len(error_window) == WINDOW_SIZE:
                error_rate = sum(error_window) / WINDOW_SIZE * 100
                if error_rate > ERROR_THRESHOLD:
                    post_to_slack(f"🚨 High error rate: {error_rate:.2f}% over last {WINDOW_SIZE} requests")

if __name__ == "__main__":
    monitor_logs()
