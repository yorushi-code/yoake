pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What the machine is doing, and what it is.
//
// Sampled by one long-lived shell loop rather than respawning readers on a QML
// Timer — a process spawn every two seconds for a handful of file reads costs
// far more than the numbers are worth. The loop emits one line, so adding a
// field costs nothing per sample.
//
// The static facts (distro, kernel, host) are read once at startup: they cannot
// change without a reboot, and a dashboard that re-reads /etc/os-release every
// two seconds to draw the same word is doing it wrong.
Singleton {
    id: root

    property real cpu: 0    // 0..1
    property real memory: 0 // 0..1

    // A minute and a half of history at the two-second poll. Long enough to
    // show a build finishing, short enough that the line still visibly moves.
    readonly property int historyLength: 45
    property var cpuHistory: []
    property var memoryHistory: []
    property int temperature: 0 // degrees C, 0 when no sensor was found

    property real memoryUsedGb: 0
    property real memoryTotalGb: 0
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    readonly property real disk: root.diskTotalGb > 0 ? root.diskUsedGb / root.diskTotalGb : 0
    property int gpuTemperature: 0
    property int uptimeSeconds: 0

    property real load1: 0
    property real swapUsedGb: 0
    property real swapTotalGb: 0
    // Bytes per second across the physical interfaces only. Summing the tunnel
    // as well would count every proxied byte twice.
    property real rxRate: 0
    property real txRate: 0

    property string distro: ""
    property string kernel: ""
    property string host: ""

    function _appended(history, sample) {
        const out = history.slice();
        out.push(sample);
        while (out.length > root.historyLength) out.shift();
        return out;
    }

    readonly property string uptimeText: {
        const s = root.uptimeSeconds;
        if (s <= 0) return "";
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0) return `${d} д ${h} ч`;
        if (h > 0) return `${h} ч ${m} мин`;
        return `${m} мин`;
    }

    function formatGb(value) {
        return value >= 100 ? value.toFixed(0) : value.toFixed(1);
    }

    function formatRate(bytesPerSecond) {
        if (bytesPerSecond < 1024) return Math.round(bytesPerSecond) + " Б/с";
        if (bytesPerSecond < 1024 * 1024) return Math.round(bytesPerSecond / 1024) + " КБ/с";
        return (bytesPerSecond / (1024 * 1024)).toFixed(1) + " МБ/с";
    }

    Process {
        running: true
        command: ["sh", "-c", `
. /etc/os-release 2>/dev/null
printf '%s\\n%s\\n%s\\n' "\${PRETTY_NAME:-Linux}" "$(uname -r)" "$(uname -n)"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.distro = (lines[0] || "").trim();
                root.kernel = (lines[1] || "").trim();
                root.host = (lines[2] || "").trim();
            }
        }
    }

    // Supervised: this loop is the only source of the numbers on the desktop,
    // and if it dies the stats freeze at their last value rather than showing
    // anything is wrong.
    ManagedProcess {
        // The hwmon index for a given chip is not stable across boots, so each
        // sensor is resolved by driver name instead of a fixed path.
        command: ["sh", "-c", `
cputemp=""
gputemp=""
for d in /sys/class/hwmon/hwmon*; do
  case "$(cat "$d/name" 2>/dev/null)" in
    k10temp|coretemp|zenpower) [ -z "$cputemp" ] && cputemp="$d/temp1_input";;
    amdgpu|nouveau|radeon)     [ -z "$gputemp" ] && gputemp="$d/temp1_input";;
  esac
done

prev_idle=0
prev_total=0
while :; do
  set -- $(head -1 /proc/stat)
  shift
  idle=$4
  total=0
  for v in "$@"; do total=$((total + v)); done
  d_total=$((total - prev_total))
  d_idle=$((idle - prev_idle))
  prev_total=$total
  prev_idle=$idle
  if [ "$d_total" -gt 0 ]; then
    cpu=$(((100 * (d_total - d_idle)) / d_total))
  else
    cpu=0
  fi

  mem_total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
  mem_avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
  mem=$((100 * (mem_total - mem_avail) / mem_total))
  mem_used=$((mem_total - mem_avail))

  temp=0
  [ -n "$cputemp" ] && [ -r "$cputemp" ] && temp=$(($(cat "$cputemp") / 1000))
  gtemp=0
  [ -n "$gputemp" ] && [ -r "$gputemp" ] && gtemp=$(($(cat "$gputemp") / 1000))

  # -P keeps it to one line per filesystem however long the device name is.
  set -- $(df -Pk / | tail -1)
  disk_used=$3
  disk_total=$2

  up=$(cut -d. -f1 /proc/uptime)

  load=$(cut -d' ' -f1 /proc/loadavg)

  swap_total=$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)
  swap_free=$(awk '/^SwapFree:/{print $2}' /proc/meminfo)
  swap_used=$((swap_total - swap_free))

  # Physical interfaces only: the tunnel carries the same bytes as the radio
  # underneath it, and counting both reports twice the traffic that exists.
  #
  # Split on the colon rather than on whitespace. /proc/net/dev right-aligns
  # the interface name in an eight-column field, so a short name has spaces
  # before it and a six-character one does not -- splitting on [: ]+ put the
  # device in $1 for some rows and $2 for others, and the counters read as
  # sixty bytes a second while a video was streaming.
  set -- $(awk '
    /:/ {
      split($0, a, ":")
      dev = a[1]
      gsub(/[ \t]/, "", dev)
      if (dev ~ /^(lo|tun|tap|veth|docker|br-|virbr|mihomo|wg)/) next
      split(a[2], f, " ")
      rx += f[1]; tx += f[9]
    }
    END { print rx+0, tx+0 }' /proc/net/dev)
  rx_now=$1
  tx_now=$2
  if [ -n "$rx_prev" ]; then
    rx_rate=$(( (rx_now - rx_prev) / 2 ))
    tx_rate=$(( (tx_now - tx_prev) / 2 ))
  else
    rx_rate=0
    tx_rate=0
  fi
  rx_prev=$rx_now
  tx_prev=$tx_now

  echo "$cpu;$mem;$temp;$mem_used;$mem_total;$disk_used;$disk_total;$up;$gtemp;$load;$swap_used;$swap_total;$rx_rate;$tx_rate"
  sleep 2
done
`]

        stdout: SplitParser {
            onRead: line => {
                const p = line.split(";");
                if (p.length < 3) return;
                root.cpu = Math.max(0, Math.min(1, parseInt(p[0]) / 100));
                root.memory = Math.max(0, Math.min(1, parseInt(p[1]) / 100));
                // Reassigned rather than pushed into: a var array mutated in
                // place notifies nothing, and the chart bound to it never
                // redraws.
                root.cpuHistory = root._appended(root.cpuHistory, root.cpu);
                root.memoryHistory = root._appended(root.memoryHistory, root.memory);
                root.temperature = parseInt(p[2]) || 0;
                if (p.length < 9) return;
                const mib = 1024 * 1024;
                root.memoryUsedGb = (parseInt(p[3]) || 0) / mib;
                root.memoryTotalGb = (parseInt(p[4]) || 0) / mib;
                root.diskUsedGb = (parseInt(p[5]) || 0) / mib;
                root.diskTotalGb = (parseInt(p[6]) || 0) / mib;
                root.uptimeSeconds = parseInt(p[7]) || 0;
                root.gpuTemperature = parseInt(p[8]) || 0;
                if (p.length < 14) return;
                root.load1 = parseFloat(p[9]) || 0;
                root.swapUsedGb = (parseInt(p[10]) || 0) / mib;
                root.swapTotalGb = (parseInt(p[11]) || 0) / mib;
                root.rxRate = Math.max(0, parseInt(p[12]) || 0);
                root.txRate = Math.max(0, parseInt(p[13]) || 0);
            }
        }
    }
}
