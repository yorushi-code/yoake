#!/usr/bin/env bash
# The music panel's ten-band equaliser.
#
# Upstream drives EasyEffects here. This fork uses a PipeWire filter-chain
# instead (no extra daemon): ten bq_peaking sections, one per slider, declared
# as a WirePlumber *smart filter*, so WirePlumber itself places it in front of
# whichever output is the default -- speakers, headphones, Bluetooth -- and
# follows when that changes.
#
#   get                 print the panel state (JSON)
#   set_band N GAIN     move one band live; marks the state as unsaved
#   apply               save: write the gains into the PipeWire config too
#   preset NAME         load a preset, live and saved
#   install             (re)write the PipeWire config from the saved state
#
# Gains move live through `pw-cli set-param`, so dragging a slider never
# restarts the graph. The config file is rewritten on save only so the curve
# survives a PipeWire restart or a reboot.

source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/caching.sh"
qs_ensure_cache "music"

STATE_FILE="$QS_STATE_MUSIC/eq_state.json"
CONF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/pipewire.conf.d/99-yoake-eq.conf"
NODE="effect_input.yoake-eq"
FREQS=(31 63 125 250 500 1000 2000 4000 8000 16000)

# One-time move of the state from its old place in the runtime dir.
if [ ! -f "$STATE_FILE" ] && [ -f "$QS_RUN_MUSIC/eq_state.json" ]; then
    cp "$QS_RUN_MUSIC/eq_state.json" "$STATE_FILE"
fi
if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0, "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0, "preset": "Flat", "pending": false}' > "$STATE_FILE"
fi

# Always as floats: the filter's controls are Float, and pw-cli passes a bare
# integer through as Int, which the node ignores.
gains() {
    jq -r '[.b1, .b2, .b3, .b4, .b5, .b6, .b7, .b8, .b9, .b10] | map(tonumber? // 0) | .[]' "$STATE_FILE" \
        | xargs printf '%.1f\n'
}

apply_live() {
    local params="" i=1 g
    while read -r g; do
        params+=" \"eq_band_${i}:Gain\" ${g}"
        i=$((i + 1))
    done < <(gains)
    pw-cli set-param "$NODE" Props "{ params = [${params} ] }" >/dev/null 2>&1
}

write_conf() {
    local nodes="" links="" i g
    local -a g_arr
    mapfile -t g_arr < <(gains)
    for i in "${!FREQS[@]}"; do
        g=${g_arr[$i]:-0}
        nodes+="                    { type = builtin name = eq_band_$((i + 1)) label = bq_peaking control = { \"Freq\" = ${FREQS[$i]}.0 \"Q\" = 1.4 \"Gain\" = ${g} } }"$'\n'
        if [ "$i" -gt 0 ]; then
            links+="                    { output = \"eq_band_${i}:Out\" input = \"eq_band_$((i + 1)):In\" }"$'\n'
        fi
    done
    mkdir -p "$(dirname "$CONF_FILE")"
    cat > "$CONF_FILE" <<EOF
# Yoake's ten-band equaliser. Written by src/quickshell/media/equalizer.sh;
# edits here are overwritten when the panel saves.
#
# filter.smart makes WirePlumber insert it in front of the default output and
# re-link it when the default changes, so it is never chosen as a device itself.
context.modules = [
    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Yoake Equalizer"
            media.name       = "Yoake Equalizer"
            filter.graph = {
                nodes = [
${nodes}                ]
                links = [
${links}                ]
            }
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {
                node.name         = "${NODE}"
                media.class       = Audio/Sink
                filter.smart      = true
                filter.smart.name = "yoake-eq"
            }
            playback.props = {
                node.name         = "effect_output.yoake-eq"
                node.passive      = true
                filter.smart      = true
                filter.smart.name = "yoake-eq"
            }
        }
    }
]
EOF
}

save_preset() {
    jq -n -c --arg b1 "$1" --arg b2 "$2" --arg b3 "$3" --arg b4 "$4" --arg b5 "$5" \
          --arg b6 "$6" --arg b7 "$7" --arg b8 "$8" --arg b9 "$9" --arg b10 "${10}" --arg p "${11}" \
       '{"b1": $b1, "b2": $b2, "b3": $b3, "b4": $b4, "b5": $b5, "b6": $b6, "b7": $b7, "b8": $b8, "b9": $b9, "b10": $b10, "preset": $p, "pending": false}' > "$STATE_FILE"
}

cmd=$1
arg1=$2
arg2=$3

case $cmd in
    "get") cat "$STATE_FILE" ;;
    "set_band")
        updated=$(jq -c --arg val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = true" "$STATE_FILE")
        echo "$updated" > "$STATE_FILE"
        apply_live
        ;;
    "apply")
        updated=$(jq -c ".pending = false" "$STATE_FILE")
        echo "$updated" > "$STATE_FILE"
        apply_live
        write_conf
        ;;
    "preset")
        case $arg1 in
            "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
            "Bass")    save_preset 5 7 5 2 1 0 0 0 1 2 "Bass" ;;
            "Treble")  save_preset -2 -1 0 1 2 3 4 5 6 6 "Treble" ;;
            "Vocal")   save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal" ;;
            "Pop")     save_preset 2 4 2 0 1 2 4 2 1 2 "Pop" ;;
            "Rock")    save_preset 5 4 2 -1 -2 -1 2 4 5 6 "Rock" ;;
            "Jazz")    save_preset 3 3 1 1 1 1 2 1 2 3 "Jazz" ;;
            "Classic") save_preset 0 1 2 2 2 2 1 2 3 4 "Classic" ;;
        esac
        apply_live
        write_conf
        ;;
    "install")
        write_conf
        ;;
esac
