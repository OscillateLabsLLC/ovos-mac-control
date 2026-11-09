#!/bin/zsh
#
# SwiftBar plugin: OVOS status, start/stop for all or single services, and
# log viewing.
#
# The filename encodes the refresh interval (5s). Copy or symlink into your
# SwiftBar plugin folder and make it executable.
#
# <bitbar.title>OVOS Control</bitbar.title>
# <bitbar.version>1.1</bitbar.version>
# <bitbar.author>Oscillate Labs</bitbar.author>
# <bitbar.desc>Start/stop the native OVOS services on macOS and view their logs.</bitbar.desc>
# <bitbar.dependencies>zsh, ovosctl</bitbar.dependencies>

export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

readonly OVOSCTL="$(command -v ovosctl)"
readonly HELPER="$HOME/.config/ovos-installer/ovos-launchd.zsh"
# Must stay in sync with LOG_DIR in ovosctl.
readonly LOG_DIR="$HOME/.local/state/mycroft/logs"

if [[ ! -x $OVOSCTL || ! -f $HELPER ]]; then
  print "OVOS ⚠️"
  print "---"
  print "ovosctl or installer helper missing | color=red"
  exit 0
fi

source "$HELPER"

# The OVOS logo silhouette as an 18pt template image, so it follows the menu
# bar's light or dark appearance. From OpenVoiceOS/ovos_assets (CC0).
readonly OVOS_ICON="iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAACXBIWXMAABYlAAAWJQFJUiTwAAADy0lEQVR42u2YSWsUQRTHf13TJjGZGJMYo0bjmpvEJQfjggsIohf1rEERQUTw4EGNH8CL38CDCF5cAiLiQQQlIuhN9KIHF9w1ZEEngUSdaS//gufYk3RPQgSxoOiqV6/+9ept9WbgH2tBQtqkANM2pw5QUJ+Wlom5QBjDF8ZcOpPmkKQtMnsiYA9wFngMHADWA0PAeeA78Ey8BbN3Sv1kM1BvNHVUhw3rwAgYEe2Y0UwDsCWpi7gUmrkCbALyorXogJnAT/Uq0eaJJw9sAC4XYZUtkDNmqgRma74AOGIOCI3vRMBhYK7ms4EK4x5uMgL5iKkC6oAmzU8Ac6QBV4SXl4aOizZXeyuLMFML5IBqjas1r9H3oDSRKbHPaykAsuLLar1mvHNdzNyrfjdwX2MPVgFsBRp106AEZgFoBjYazdTo2wvsMqZ24+UMm9gWAR0az9R3DrDPRNV4gRAB+w2f13YHsETjn6WSWKCNrcAo0Ce7RwLyGuqUT0yU7Hxq2Cksr+WsMOtFa9Jl33oZik12DzitcbOYGoFa0doVYRPlFL/WCqwxAjVqzUdgt8784x2KxLRMIGizFyybJEImyGNZE6Uee7HObBKfc+Y2q0Scp3m9Eah2CjJ+rbAstk+g7V6z9qVeJ+Ga5QN1oreY8WRaHbDQJMuM8cdOb7HQmK1T0jZJiFrNF+qxnGxrUAqIZL4FxlTrvBwhMKYNa00iWyrvD4D5QG4KXux6YJYwq4HlOitQKigAYyFwTgI06OXOAtv0HQPagG/aGKR05hGTw5ZKqFFhb5HZcqJfA14DnFH4tck8vZL2EbBa5vqhWicy9U2S/sOMC7rgKuCh3rxeuccKydAdd7MuAfRoPijN3TIlRZSy5ySQT5I9ondR4u0KgRmaf9DaV5nIa+ZOGXW412avhMpp/zfR3+vMGV4OZ4qrvADeCcwL0qcNt42QSR3c+901Yfdr76Dob0XPezlcTEb9LKYhMw+A58Bd0fIJtRMAH4GbutQnreWE8bm4kiwWKBDzoL4IcETr51OYzT8zF4X33bjDIDAg3N80HpYA22FuM2AEeKKwrdSBbpyQzyjKLhjT9Wv9KvCg3ITWCZwyKf+LiZ64iCvIHyLx+mfnpDJy2b9GgxJ1zhs5/rDJNbbbUH9Vom4KSmnXTRCunscXXD4argPbgZcmbfg+DBwCLhkt+oLOGZPGljJhCufMCNxHyCO9QXtVO1cAT4EbwAtgpQkMlzAyEwlU3B4rBTgluIvqxaZ9rsc0VTIt59+PjFF5XG1dMGvBdP4b8r/9lfYLCEsWPAYiIokAAAAASUVORK5CYII="

# Must stay in sync with GUI_SERVICES and gui_label in ovosctl.
typeset -ra GUI_SERVICES=(ovos-gui ovos-homescreen ovos-visage ovos-visage-app)

for service in $GUI_SERVICES; do
  _OVOS_LAUNCHD_LABEL_BY_SERVICE[$service]="com.oscillatelabs.$service"
  _OVOS_LAUNCHD_PLIST_BY_SERVICE[$service]="$HOME/Library/LaunchAgents/com.oscillatelabs.$service.plist"
done

typeset -a installed gui_installed running_services

service_is_running() {
  launchctl print "gui/$(id -u)/${_OVOS_LAUNCHD_LABEL_BY_SERVICE[$1]}" 2>/dev/null \
    | grep -q "state = running"
}

collect_state() {
  local service
  for service in "${_OVOS_LAUNCHD_USER_SERVICES[@]}"; do
    [[ -f "${_OVOS_LAUNCHD_PLIST_BY_SERVICE[$service]}" ]] || continue
    installed+=("$service")
    service_is_running "$service" && running_services+=("$service")
  done
  for service in $GUI_SERVICES; do
    [[ -f "${_OVOS_LAUNCHD_PLIST_BY_SERVICE[$service]}" ]] || continue
    gui_installed+=("$service")
    service_is_running "$service" && running_services+=("$service")
  done
}

count_running() {
  local service n=0
  for service in "$@"; do
    (( ${running_services[(Ie)$service]} )) && (( n++ ))
  done
  print $n
}

# The GUI is meant to be always on, so it only shows in the title when it is not.
gui_title_suffix() {
  local running=$(count_running $gui_installed) total=${#gui_installed}
  (( total == 0 || running == total )) && return
  print -n " 🖥$running/$total"
}

# A partial state must look different from a healthy one at a glance, so only
# an all-up system gets the bare icon.
print_title() {
  local running=$(count_running $installed) total=${#installed} suffix=$(gui_title_suffix) state=""
  if (( total == 0 )); then
    print "OVOS ⚠️$suffix"
    return
  fi
  if (( running == 0 )); then
    state="off"
  elif (( running < total )); then
    state="$running/$total"
  fi
  print -r -- "$state$suffix | templateImage=$OVOS_ICON"
}

ovosctl_item() {
  local label=$1; shift
  local -a params=()
  local i=1 arg
  for arg in "$@"; do
    params+=("param$i=$arg")
    (( i++ ))
  done
  print -r -- "$label | bash=$OVOSCTL $params terminal=false refresh=true"
}

print_global_actions() {
  local running=$(count_running $installed) total=${#installed}
  if (( running == total && total > 0 )); then
    print "OVOS is running | color=green"
    ovosctl_item "Stop OVOS" stop
  elif (( running == 0 )); then
    print "OVOS is stopped | color=gray"
    ovosctl_item "Start OVOS" start
  else
    print "OVOS is partially up ($running/$total) | color=orange"
    ovosctl_item "Restart OVOS" restart
    ovosctl_item "Stop OVOS" stop
  fi
}

# Console.app updates live and is searchable; the terminal tail is there for
# when you want it scrolling beside something else.
print_log_items() {
  local service=$1 log="$LOG_DIR/$1.log" err="$LOG_DIR/$1.err"
  # Submenu lines start with "--", which print would parse as options without -r --.
  [[ -f $log ]] && print -r -- "--View log | bash=/usr/bin/open param1=-a param2=Console param3=$log terminal=false"
  [[ -f $log ]] && print -r -- "--Tail log in Terminal | bash=$OVOSCTL param1=logs param2=$service terminal=true"
  # An empty .err means a clean run, so only offer it when there is something to see.
  [[ -s $err ]] && print -r -- "--View errors | bash=/usr/bin/open param1=-a param2=Console param3=$err terminal=false"
  [[ -s $err ]] && print -r -- "--Tail errors in Terminal | bash=$OVOSCTL param1=logs param2=$service param3=err terminal=true"
}

# Needs SwiftBar >= 2.1.2: in 2.1.1, a submenu parent whose title or children
# change between refreshes goes disabled, and rows can duplicate.
print_service_menu() {
  local service=$1
  if (( ${running_services[(Ie)$service]} )); then
    print "✅ $service | font=Menlo size=12"
    ovosctl_item "--Stop" stop "$service"
  else
    print "⭕️ $service | font=Menlo size=12"
    ovosctl_item "--Start" start "$service"
  fi
  ovosctl_item "--Restart" restart "$service"
  print -- "-----"
  print_log_items "$service"
}

print_gui_actions() {
  local running=$(count_running $gui_installed) total=${#gui_installed}
  if (( running == total )); then
    print "GUI is running | color=green"
    ovosctl_item "Open Visage" gui open
    ovosctl_item "Stop GUI" gui stop
  elif (( running == 0 )); then
    print "GUI is stopped | color=gray"
    ovosctl_item "Start GUI" gui start
  else
    print "GUI is partially up ($running/$total) | color=orange"
    ovosctl_item "Restart GUI" gui restart
    ovosctl_item "Stop GUI" gui stop
  fi
}

collect_state
print_title
print -- "---"
print_global_actions
print -- "---"
for service in $installed; do
  print_service_menu "$service"
done
if (( ${#gui_installed} )); then
  print -- "---"
  print_gui_actions
  for service in $gui_installed; do
    print_service_menu "$service"
  done
fi
print -- "---"
print "Logs folder | bash=/usr/bin/open param1=$LOG_DIR terminal=false"
print "Refresh | refresh=true"
