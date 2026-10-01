# The tool catalog uses one assignment per line, including inline TOML tables.
# Preserve each assignment verbatim when projecting selected keys.
function fail(message) {
  print FILENAME ":" FNR ": " message > "/dev/stderr"
  failed = 1
  exit 1
}
/^\[tools\]$/ { if (tools_section++) fail("duplicate tools section"); in_tools = 1; next }
/^[[:space:]]*\[+tools([[:space:]."]|\])/ { fail("tool subtables and alternate headers are unsupported; use one-line assignments") }
/^\[/ { in_tools = 0 }
!in_tools || /^[[:space:]]*(#.*)?$/ { next }
{
  if ($0 !~ /^[[:space:]]*("[A-Za-z0-9:._\/-]+"|[A-Za-z0-9_-]+)[[:space:]]*=[[:space:]]*("[^"[:cntrl:]]+"|\{.*\})[[:space:]]*$/)
    fail("unsupported tool assignment; use a pinned string or one-line inline table")
  key = $0
  sub(/[[:space:]]*=.*/, "", key)
  gsub(/"/, "", key); gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
  if (key in entries) fail("duplicate catalog key: " key)
  order[++count] = key
  entries[key] = $0
}
END {
  if (failed) exit 1
  if (!count) fail("tool catalog is empty")
  selected_count = split(selected, members, " ")
  for (i = 1; i <= selected_count; i++) {
    if (!(members[i] in entries)) fail("unknown selected tool: " members[i])
    wanted[members[i]] = 1
  }
  if (action == "keys") {
    for (i = 1; i <= count; i++) printf "%s%s", (i == 1 ? "" : " "), order[i]
    print ""
  } else if (action == "entries") {
    for (i = 1; i <= count; i++) if (order[i] in wanted) print entries[order[i]]
  } else fail("unknown catalog action: " action)
}
