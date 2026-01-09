import asyncio
import httpx
import psutil
import time
import subprocess
import sys
import ssl
import socket
import os
from datetime import datetime

# --- CONFIGURATION & ARGUMENTS ---
if len(sys.argv) > 1:
    VPS_NAME = sys.argv[1]
else:
    VPS_NAME = input("Enter VPS Name: ")

if len(sys.argv) > 2:
    USE_PROXY = True if sys.argv[2].upper() == "P" else False
else:
    USE_PROXY = False

if len(sys.argv) > 3:
    ENABLE_TEST_DOMAINS = 1 if sys.argv[3].upper() == "TEST" else 0
else:
    ENABLE_TEST_DOMAINS = 0

# --- PROXY & ENDPOINT ---
PROXY_URL = "http://admin:password@YOUR_HOME_IP:8080"
PUSHGATEWAY_URL = f"http://110.169.136.23:8282/metrics/job/vps_monitor/instance/{VPS_NAME}"
CHECK_INTERVAL = 3600
TIMEOUT = 20
TEST_DOMAINS = ["google.com", "facebook.com"]

# --- LOGGING ---
def log_info(msg): print(f"[{datetime.now().strftime('%H:%M:%S')}] [INFO] {msg}")
def log_success(msg): print(f"[{datetime.now().strftime('%H:%M:%S')}] \033[92m[PASS]\033[0m {msg}")
def log_warn(msg): print(f"[{datetime.now().strftime('%H:%M:%S')}] \033[93m[WARN]\033[0m {msg}")
def log_error(msg): print(f"[{datetime.now().strftime('%H:%M:%S')}] \033[91m[FAIL]\033[0m {msg}")

def get_ssl_expiry_days(domain):
    try:
        context = ssl.create_default_context()
        with socket.create_connection((domain, 443), timeout=5) as sock:
            with context.wrap_socket(sock, server_hostname=domain) as ssock:
                cert = ssock.getpeercert()
                expiry_date = datetime.strptime(cert['notAfter'], '%b %d %H:%M:%S %Y %Z')
                delta = expiry_date - datetime.now()
                return delta.days
    except:
        return -1

def get_cpanel_domains():
    try:
        cmd = 'uapi DomainInfo list_domains | grep -E "^\s*-\s|^  main_domain:" | sed "s/.*- //" | sed "s/.*main_domain: //"'
        result = subprocess.check_output(cmd, shell=True).decode("utf-8")
        domains = [d.strip() for d in result.strip().split('\n') if d.strip()]
        return list(set(domains))
    except Exception as e:
        log_error(f"Cannot fetch domains: {e}")
        return []

async def check_domain(client, domain, semaphore):
    async with semaphore:
        url = f"http://{domain}"
        is_healthy, latency, status_code, ssl_days = 0, 0, 0, -1
        error_type = "none"
        reason = "Unknown"

        try:
            headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36'}
            start_time = time.time()
            resp = await client.get(url, timeout=TIMEOUT, follow_redirects=True, headers=headers)
            latency = time.time() - start_time
            status_code = resp.status_code
            content = resp.text.lower()

            # à¸•à¸£à¸§à¸ˆà¸ªà¸­à¸šà¸›à¸£à¸°à¹€à¸ à¸— Error à¸ªà¸³à¸«à¸£à¸±à¸š Label à¹à¸¥à¸° Log
            if "facebook" not in content:
                error_type = "missing_facebook_keyword"
                reason = "Facebook missing or Thin content"
            elif len(content) < 500:
                error_type = "thin_content"
                reason = "Content too short"
            else:
                bad_keywords = ["database error", "error establishing", "access denied", "connection refused"]
                found_bad = [kw for kw in bad_keywords if kw in content]
                if found_bad:
                    error_type = "bad_keyword_detected"
                    reason = f"Found: {found_bad[0]}"
                else:
                    is_healthy = 1
                    error_type = "none"
                    reason = "OK"

            loop = asyncio.get_event_loop()
            ssl_days = await loop.run_in_executor(None, get_ssl_expiry_days, domain)

        except Exception as e:
            error_type = type(e).__name__
            reason = error_type

        # Metrics data à¸ªà¸³à¸«à¸£à¸±à¸š Pushgateway
        m = f'web_status{{domain="{domain}", vps="{VPS_NAME}", reason="{error_type}"}} {is_healthy}\n'
        m += f'web_latency{{domain="{domain}", vps="{VPS_NAME}"}} {latency:.4f}\n'
        m += f'web_http_status{{domain="{domain}", vps="{VPS_NAME}"}} {status_code}\n'
        m += f'web_ssl_expiry_days{{domain="{domain}", vps="{VPS_NAME}"}} {ssl_days}\n'

        # --- à¹à¸à¹‰à¹„à¸‚à¸ªà¹ˆà¸§à¸™à¸à¸²à¸£à¹à¸ªà¸”à¸‡à¸œà¸¥ Log à¹ƒà¸«à¹‰à¸¥à¸°à¹€à¸­à¸µà¸¢à¸”à¸‚à¸¶à¹‰à¸™ ---
        if is_healthy:
            log_success(f"{domain} - OK | SSL: {ssl_days}d")
        else:
            log_warn(f"{domain} - FAIL: {reason} | Code: {status_code}")

        return m, is_healthy

async def collect_metrics():
    log_info(f"--- Scan Start: {VPS_NAME} | Proxy: {'ON' if USE_PROXY else 'OFF'} | Test: {'ON' if ENABLE_TEST_DOMAINS else 'OFF'} ---")

    cpu = psutil.cpu_percent(interval=1)
    ram = psutil.virtual_memory().percent

    domains = get_cpanel_domains()
    if ENABLE_TEST_DOMAINS:
        domains.extend(TEST_DOMAINS)
        domains = list(set(domains))

    if not domains:
        log_warn("No domains to scan.")
        return

    semaphore = asyncio.Semaphore(20)
    client_kwargs = {"verify": False, "follow_redirects": True}

    if USE_PROXY:
        client_kwargs["proxy"] = PROXY_URL

    try:
        async with httpx.AsyncClient(**client_kwargs) as client:
            tasks = [check_domain(client, d, semaphore) for d in domains]
            results = await asyncio.gather(*tasks)
    except TypeError:
        # Fallback à¸ªà¸³à¸«à¸£à¸±à¸š httpx version à¹€à¸à¹ˆà¸²
        if USE_PROXY:
            client_kwargs["proxies"] = PROXY_URL
            if "proxy" in client_kwargs: del client_kwargs["proxy"]
        async with httpx.AsyncClient(**client_kwargs) as client:
            tasks = [check_domain(client, d, semaphore) for d in domains]
            results = await asyncio.gather(*tasks)

    metrics_data = f'vps_cpu_usage{{vps="{VPS_NAME}"}} {cpu}\n'
    metrics_data += f'vps_ram_usage{{vps="{VPS_NAME}"}} {ram}\n'
    metrics_data += "".join([r[0] for r in results])

    up_count = sum([r[1] for r in results])
    log_info(f"Summary: Total {len(domains)} | UP {up_count} | DOWN {len(domains) - up_count}")

    try:
        async with httpx.AsyncClient() as push_client:
            await push_client.post(PUSHGATEWAY_URL, content=metrics_data)
            log_info("Pushed metrics successfully")
    except Exception as e:
        log_error(f"Push Failed: {e}")

if __name__ == "__main__":
    log_info(f"Agent Starting... (VPS: {VPS_NAME})")
    with open("agent.pid", "w") as f:
        f.write(str(os.getpid()))

    while True:
        try:
            asyncio.run(collect_metrics())
        except KeyboardInterrupt:
            log_info("Agent Stopping...")
            sys.exit(0)
        except Exception as e:
            log_error(f"Main Loop Error: {e}")
        time.sleep(CHECK_INTERVAL)
