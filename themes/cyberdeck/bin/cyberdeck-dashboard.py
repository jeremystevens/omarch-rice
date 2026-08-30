#!/usr/bin/env python3
import curses
import os
import socket
import subprocess
import threading
import time

REFRESH = 1.5
WEATHER_REFRESH = 300


def read_file(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def hostname():
    return socket.gethostname()


def os_pretty_name():
    for line in read_file("/etc/os-release").splitlines():
        if line.startswith("PRETTY_NAME="):
            return line.split("=", 1)[1].strip('"')
    return "Linux"


def kernel():
    return read_file("/proc/version").split()[2] if read_file("/proc/version") else "?"


def uptime_str():
    raw = read_file("/proc/uptime")
    if not raw:
        return "?"
    seconds = int(float(raw.split()[0]))
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, _ = divmod(rem, 60)
    if days:
        return f"{days}d {hours}h {minutes}m"
    return f"{hours}h {minutes}m"


def load_avg():
    return os.getloadavg()


def cpu_times():
    line = read_file("/proc/stat").splitlines()[0]
    parts = [int(x) for x in line.split()[1:]]
    idle = parts[3] + parts[4]
    total = sum(parts)
    return idle, total


def cpu_percent(prev, cur):
    idle_delta = cur[0] - prev[0]
    total_delta = cur[1] - prev[1]
    if total_delta <= 0:
        return 0.0
    return max(0.0, min(100.0, 100.0 * (1 - idle_delta / total_delta)))


def mem_info():
    values = {}
    for line in read_file("/proc/meminfo").splitlines():
        parts = line.split()
        if len(parts) >= 2:
            values[parts[0].rstrip(":")] = int(parts[1])
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", 0)
    used = total - available
    pct = 100.0 * used / total if total else 0.0
    return used / 1048576, total / 1048576, pct


def cpu_temp_c():
    for i in range(6):
        raw = read_file(f"/sys/class/thermal/thermal_zone{i}/temp").strip()
        if raw.isdigit():
            return int(raw) / 1000.0
    return None


def disk_usage(mount="/"):
    st = os.statvfs(mount)
    total = st.f_frsize * st.f_blocks
    free = st.f_frsize * st.f_bavail
    used = total - free
    pct = 100.0 * used / total if total else 0.0
    return used / (1 << 30), total / (1 << 30), pct


def net_dev():
    stats = {}
    lines = read_file("/proc/net/dev").splitlines()[2:]
    for line in lines:
        if ":" not in line:
            continue
        name, rest = line.split(":", 1)
        name = name.strip()
        if name == "lo":
            continue
        fields = rest.split()
        stats[name] = (int(fields[0]), int(fields[8]))
    return stats


def local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return "unassigned"
    finally:
        s.close()


def top_processes(n=5):
    try:
        out = subprocess.run(
            ["ps", "-eo", "comm,pcpu,pmem", "--sort=-pcpu", "--no-headers"],
            capture_output=True, text=True, timeout=1,
        ).stdout
    except Exception:
        return []
    rows = []
    for line in out.splitlines()[:n]:
        parts = line.split()
        if len(parts) >= 3:
            rows.append((parts[0][:16], parts[1], parts[2]))
    return rows


class WeatherFetcher:
    def __init__(self):
        self.text = "SYNCING..."
        self._lock = threading.Lock()
        threading.Thread(target=self._loop, daemon=True).start()

    def _loop(self):
        while True:
            try:
                out = subprocess.run(
                    ["omarchy-weather-status"], capture_output=True, text=True, timeout=6,
                ).stdout.strip()
            except Exception:
                out = ""
            with self._lock:
                self.text = out if out else "OFFLINE"
            time.sleep(WEATHER_REFRESH)

    def get(self):
        with self._lock:
            return self.text


def bar(pct, width, filled_attr, empty_attr):
    filled = int(round(width * min(100.0, max(0.0, pct)) / 100.0))
    return "█" * filled, "░" * (width - filled)


def level_attr(pct, colors):
    if pct >= 85:
        return colors["red"]
    if pct >= 60:
        return colors["yellow"]
    return colors["green"]


def draw_panel(win, y, x, w, h, title, colors):
    win.attron(colors["cyan"])
    win.addstr(y, x, "┌" + "─" * (w - 2) + "┐")
    label = f" {title} "
    win.addstr(y, x + 2, label)
    for row in range(1, h - 1):
        win.addstr(y + row, x, "│")
        win.addstr(y + row, x + w - 1, "│")
    win.addstr(y + h - 1, x, "└" + "─" * (w - 2) + "┘")
    win.attroff(colors["cyan"])


def safe_addstr(win, y, x, text, attr=0):
    try:
        win.addstr(y, x, text, attr)
    except curses.error:
        pass


def run(stdscr):
    curses.curs_set(0)
    stdscr.nodelay(True)
    curses.start_color()
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_CYAN, -1)
    curses.init_pair(2, curses.COLOR_GREEN, -1)
    curses.init_pair(3, curses.COLOR_YELLOW, -1)
    curses.init_pair(4, curses.COLOR_RED, -1)
    curses.init_pair(5, curses.COLOR_WHITE, -1)
    colors = {
        "cyan": curses.color_pair(1) | curses.A_BOLD,
        "green": curses.color_pair(2),
        "yellow": curses.color_pair(3),
        "red": curses.color_pair(4) | curses.A_BOLD,
        "dim": curses.color_pair(5),
    }

    weather = WeatherFetcher()
    prev_cpu = cpu_times()
    prev_net = net_dev()
    prev_time = time.time()

    while True:
        ch = stdscr.getch()
        if ch in (ord("q"), ord("Q"), 27):
            return

        stdscr.erase()
        h, w = stdscr.getmaxyx()
        if h < 20 or w < 70:
            safe_addstr(stdscr, 0, 0, "Terminal too small — resize to at least 70x20.", colors["yellow"])
            stdscr.refresh()
            time.sleep(REFRESH)
            continue

        now = time.time()
        cur_cpu = cpu_times()
        pct_cpu = cpu_percent(prev_cpu, cur_cpu)
        prev_cpu = cur_cpu

        cur_net = net_dev()
        dt = max(0.001, now - prev_time)
        rx_total = sum(v[0] for v in cur_net.values())
        tx_total = sum(v[1] for v in cur_net.values())
        prx_total = sum(v[0] for v in prev_net.values())
        ptx_total = sum(v[1] for v in prev_net.values())
        rx_rate = max(0.0, (rx_total - prx_total) / dt / 1024)
        tx_rate = max(0.0, (tx_total - ptx_total) / dt / 1024)
        prev_net = cur_net
        prev_time = now

        mem_used, mem_total, mem_pct = mem_info()
        temp = cpu_temp_c()
        ts = time.strftime("%Y-%m-%d %H:%M:%S")

        header = "C Y B E R // D E C K   C O N T R O L   P A N E L"
        safe_addstr(stdscr, 0, max(0, (w - len(header)) // 2), header, colors["cyan"])
        safe_addstr(stdscr, 1, max(0, (w - len(ts)) // 2), ts, colors["dim"])

        col_w = (w - 3) // 2
        left_x = 0
        right_x = col_w + 2
        top_y = 3

        # SYSTEM panel
        sys_h = 7
        draw_panel(stdscr, top_y, left_x, col_w, sys_h, "SYS//NODE", colors)
        safe_addstr(stdscr, top_y + 1, left_x + 2, f"HOST     {hostname()}"[:col_w - 3], colors["dim"])
        safe_addstr(stdscr, top_y + 2, left_x + 2, f"OS       {os_pretty_name()}"[:col_w - 3], colors["dim"])
        safe_addstr(stdscr, top_y + 3, left_x + 2, f"KERNEL   {kernel()}"[:col_w - 3], colors["dim"])
        safe_addstr(stdscr, top_y + 4, left_x + 2, f"UPTIME   {uptime_str()}"[:col_w - 3], colors["dim"])
        temp_s = f"{temp:.0f}C" if temp is not None else "N/A"
        safe_addstr(stdscr, top_y + 5, left_x + 2, f"CPU TEMP {temp_s}"[:col_w - 3], colors["dim"])

        # CPU/MEM panel
        cm_y = top_y + sys_h + 1
        cm_h = 6
        draw_panel(stdscr, cm_y, left_x, col_w, cm_h, "CPU // MEM", colors)
        bar_w = col_w - 20
        filled, empty = bar(pct_cpu, bar_w, colors["green"], colors["dim"])
        safe_addstr(stdscr, cm_y + 1, left_x + 2, f"CPU {pct_cpu:5.1f}% ", colors["dim"])
        safe_addstr(stdscr, cm_y + 1, left_x + 13, filled, level_attr(pct_cpu, colors))
        safe_addstr(stdscr, cm_y + 1, left_x + 13 + len(filled), empty, colors["dim"])
        la1, la5, la15 = load_avg()
        safe_addstr(stdscr, cm_y + 2, left_x + 2, f"LOAD {la1:.2f} {la5:.2f} {la15:.2f}"[:col_w - 3], colors["dim"])
        filledm, emptym = bar(mem_pct, bar_w, colors["green"], colors["dim"])
        safe_addstr(stdscr, cm_y + 3, left_x + 2, f"MEM {mem_pct:5.1f}% ", colors["dim"])
        safe_addstr(stdscr, cm_y + 3, left_x + 13, filledm, level_attr(mem_pct, colors))
        safe_addstr(stdscr, cm_y + 3, left_x + 13 + len(filledm), emptym, colors["dim"])
        safe_addstr(stdscr, cm_y + 4, left_x + 2, f"{mem_used:.1f} / {mem_total:.1f} GiB"[:col_w - 3], colors["dim"])

        # DISK panel
        disk_y = cm_y + cm_h + 1
        disk_h = 4
        draw_panel(stdscr, disk_y, left_x, col_w, disk_h, "STORAGE", colors)
        du, dt_, dpct = disk_usage("/")
        filledd, emptyd = bar(dpct, bar_w, colors["green"], colors["dim"])
        safe_addstr(stdscr, disk_y + 1, left_x + 2, f"/   {dpct:5.1f}% ", colors["dim"])
        safe_addstr(stdscr, disk_y + 1, left_x + 13, filledd, level_attr(dpct, colors))
        safe_addstr(stdscr, disk_y + 1, left_x + 13 + len(filledd), emptyd, colors["dim"])
        safe_addstr(stdscr, disk_y + 2, left_x + 2, f"{du:.1f} / {dt_:.1f} GiB"[:col_w - 3], colors["dim"])

        # NETWORK panel (right column)
        net_h = 6
        draw_panel(stdscr, top_y, right_x, col_w, net_h, "NETWORK", colors)
        safe_addstr(stdscr, top_y + 1, right_x + 2, f"IP    {local_ip()}"[:col_w - 3], colors["dim"])
        ifaces = ", ".join(sorted(cur_net.keys())[:3]) or "none"
        safe_addstr(stdscr, top_y + 2, right_x + 2, f"IFACE {ifaces}"[:col_w - 3], colors["dim"])
        safe_addstr(stdscr, top_y + 3, right_x + 2, f"DOWN  {rx_rate:8.1f} KB/s", colors["green"])
        safe_addstr(stdscr, top_y + 4, right_x + 2, f"UP    {tx_rate:8.1f} KB/s", colors["yellow"])

        # PROCESSES panel
        proc_y = top_y + net_h + 1
        proc_h = 8
        draw_panel(stdscr, proc_y, right_x, col_w, proc_h, "TOP PROCESSES", colors)
        safe_addstr(stdscr, proc_y + 1, right_x + 2, f"{'NAME':<16}{'CPU%':>7}{'MEM%':>7}", colors["cyan"])
        for i, (name, pcpu, pmem) in enumerate(top_processes()):
            safe_addstr(stdscr, proc_y + 2 + i, right_x + 2, f"{name:<16}{pcpu:>7}{pmem:>7}", colors["dim"])

        # WEATHER panel
        wx_y = proc_y + proc_h + 1
        wx_h = 3
        draw_panel(stdscr, wx_y, right_x, col_w, wx_h, "WEATHER", colors)
        safe_addstr(stdscr, wx_y + 1, right_x + 2, weather.get()[:col_w - 3], colors["dim"])

        footer_y = h - 1
        footer = "[ Q ] DISCONNECT      NODE STATUS: SECURED      CYBER//DECK v1.0"
        safe_addstr(stdscr, footer_y, max(0, (w - len(footer)) // 2), footer, colors["dim"])

        stdscr.refresh()
        time.sleep(REFRESH)


def main():
    curses.wrapper(run)


if __name__ == "__main__":
    main()
