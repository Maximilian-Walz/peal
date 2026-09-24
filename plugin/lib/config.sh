# shellcheck shell=bash
# The effective configuration: Peal's defaults (lib/config-defaults.yml) with the
# project's .peal/config.yml over them. The file is optional; unknown keys in it are
# refused.

PEAL_CONFIG_FILE=.peal/config.yml

# peal_config_load -> fills PEAL_CONFIG with the effective settings as yaml-parse.awk
# records; status 2 and a message if the project's file is not valid.
peal_config_load() {
  local top defaults project=""
  top=$(peal_project_root) || return 2
  defaults=$(awk -v mode=config -v name="$PEAL_ROOT/lib/config-defaults.yml" \
    -f "$PEAL_ROOT/lib/yaml-parse.awk" "$PEAL_ROOT/lib/config-defaults.yml") || return 2
  if [ -f "$top/$PEAL_CONFIG_FILE" ]; then
    project=$(awk -v mode=config -v name="$PEAL_CONFIG_FILE" \
      -f "$PEAL_ROOT/lib/yaml-parse.awk" "$top/$PEAL_CONFIG_FILE") || return 2
  fi
  PEAL_CONFIG=$(awk -F '\t' -v name="$PEAL_CONFIG_FILE" -f "$PEAL_ROOT/lib/config-merge.awk" \
    <(printf '%s\n' "$defaults") <(printf '%s\n' "$project")) || return 2
}

# peal_config_print -> every effective setting as "key: value", nested keys dotted.
peal_config_print() {
  printf '%s\n' "$PEAL_CONFIG" \
    | awk -F '\t' -f "$PEAL_ROOT/lib/yaml-render.awk" -f "$PEAL_ROOT/lib/config-print.awk"
}

# peal_config_get KEY -> a setting's value, or a list's items one per line; for a group
# (sizes, plan, ...) its settings as "key: value". Status 2 for an unknown KEY.
peal_config_get() {
  local key=$1 group
  if printf '%s\n' "$PEAL_CONFIG" | awk -F '\t' -v key="$key" '
      $1 == key { found = 1; if (($2 == "s" && $4 != "") || $2 == "i") print $4 }
      END { exit !found }'; then
    return 0
  fi
  group=$(printf '%s\n' "$PEAL_CONFIG" \
    | awk -F '\t' -v prefix="$key." 'index($1, prefix) == 1 { print substr($0, length(prefix) + 1) }')
  if [ -z "$group" ]; then
    peal_err "unknown setting $key"
    return 2
  fi
  printf '%s\n' "$group" \
    | awk -F '\t' -f "$PEAL_ROOT/lib/yaml-render.awk" -f "$PEAL_ROOT/lib/config-print.awk"
}
