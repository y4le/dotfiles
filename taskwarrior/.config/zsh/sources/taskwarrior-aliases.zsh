if ! command -v task &>/dev/null; then
  return 0
  echo 'taskwarrior not installed'
fi

export TASKD_HOST="yale.c.googlers.com"
export TASKD_PORT="53589"

function taskd-up() {
  ssh -fNTML $TASKD_PORT\:localhost\:$TASKD_PORT $TASKD_HOST
}

function taskd-status() {
  ssh -TO check $TASKD_HOST
}

function taskd-down() {
  ssh -TO exit $TASKD_HOST
}

function task() {
  command task "$@"

  if [[ $* =~ sync* ]]; then # if command contains 'sync'
    if [[ $? == 0 ]]; then # if last command failed
      if ! taskd-status &>/dev/null; then # if the tunnel is down
        echo 'opening tunnel to taskd server'
        taskd-up
        command task "$@"
      fi
    fi
  fi
}
