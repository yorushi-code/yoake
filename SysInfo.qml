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
    property int temperature: 0 // degrees C, 0 when no sensor was found

    property real memoryUsedGb: 0
    property real memoryTotalGb: 0
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    readonly property real disk: root.diskTotalGb > 0 ? root.diskUsedGb / root.diskTotalGb : 0
    property int gpuTemperature: 0
    property int uptimeSeconds: 0

    property string distro: ""
    property string kernel: ""
    property string host: ""

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

  echo "$cpu;$mem;$temp;$mem_used;$mem_total;$disk_used;$disk_total;$up;$gtemp"
  sleep 2
done
`]

        stdout: SplitParser {
            onRead: line => {
                const p = line.split(";");
                if (p.length < 3) return;
                root.cpu = Math.max(0, Math.min(1, parseInt(p[0]) / 100));
                root.memory = Math.max(0, Math.min(1, parseInt(p[1]) / 100));
                root.temperature = parseInt(p[2]) || 0;
                if (p.length < 9) return;
                const mib = 1024 * 1024;
                root.memoryUsedGb = (parseInt(p[3]) || 0) / mib;
                root.memoryTotalGb = (parseInt(p[4]) || 0) / mib;
                root.diskUsedGb = (parseInt(p[5]) || 0) / mib;
                root.diskTotalGb = (parseInt(p[6]) || 0) / mib;
                root.uptimeSeconds = parseInt(p[7]) || 0;
                root.gpuTemperature = parseInt(p[8]) || 0;
            }
        }
    }
}
