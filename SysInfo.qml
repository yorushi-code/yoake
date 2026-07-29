pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU / RAM / temperature, sampled by one long-lived shell loop rather than
// respawning readers on a QML Timer — a process spawn every two seconds for
// three trivial file reads is far more expensive than the numbers are worth.
Singleton {
    id: root

    property real cpu: 0    // 0..1
    property real memory: 0 // 0..1
    property int temperature: 0 // degrees C, 0 when no sensor was found

    // Supervised: this loop is the only source of the numbers on the desktop,
    // and if the shell dies the stats freeze at their last value rather than
    // showing anything is wrong.
    ManagedProcess {
        // The hwmon index for a given chip is not stable across boots, so the
        // CPU sensor is resolved by driver name instead of a fixed path.
        command: ["sh", "-c", `
tempfile=""
for d in /sys/class/hwmon/hwmon*; do
  case "$(cat "$d/name" 2>/dev/null)" in
    k10temp|coretemp|zenpower) tempfile="$d/temp1_input"; break;;
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

  temp=0
  if [ -n "$tempfile" ] && [ -r "$tempfile" ]; then
    temp=$(($(cat "$tempfile") / 1000))
  fi

  echo "$cpu;$mem;$temp"
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
            }
        }
    }
}
