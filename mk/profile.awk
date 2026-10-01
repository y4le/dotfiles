# Parse the deliberately small YAML shape in setup/profiles.yaml. Reject syntax
# we do not understand instead of silently applying a partial setup.
function fail(message) {
  print FILENAME ":" FNR ": " message > "/dev/stderr"
  failed = 1
  exit 1
}

function parse_list(raw, label,    body, count, items, i, result, seen) {
  if (substr(raw, 1, 1) != "[" || substr(raw, length(raw), 1) != "]")
    fail("expected a list for " label)
  body = substr(raw, 2, length(raw) - 2)
  if (body == "")
    return ""
  count = split(body, items, ", ")
  result = ""
  for (i = 1; i <= count; i++) {
    if (items[i] !~ /^[A-Za-z0-9:._\/-]+$/)
      fail("invalid list item in " label ": " items[i])
    if (seen[items[i]]++)
      fail("duplicate list item in " label ": " items[i])
    result = result (result == "" ? "" : " ") items[i]
  }
  return result
}

function add_selected(name) {
  if (!(name in components))
    fail("unknown component: " name)
  if (!(name in selected)) {
    selected[name] = 1
    selected_order[++selected_count] = name
  }
}

function emit_members(kind, all,    i, count, names, j, name, item, output, seen) {
  output = ""
  for (i = 1; i <= component_count; i++) {
    name = component_order[i]
    if (!all && !(name in selected)) continue
    count = split(kind == "packages" ? packages[name] : tools[name], names, " ")
    for (j = 1; j <= count; j++) {
      item = names[j]
      if (item != "" && !(item in seen)) {
        seen[item] = 1
        if (kind == "packages") output = output (output == "" ? "" : " ") item
      }
    }
  }
  if (kind == "tools") {
    count = split(catalog_tools, names, " ")
    for (i = 1; i <= count; i++)
      if (names[i] in seen) output = output (output == "" ? "" : " ") names[i]
  }
  print output
}

function presets(name,    i, result) {
  result = ""
  for (i = 1; i <= profile_count; i++)
    if (index(" " profiles[profile_order[i]] " ", " " name " "))
      result = result (result == "" ? "" : ", ") profile_order[i]
  return result == "" ? "optional" : result
}

BEGIN {
  section = ""
  current_component = ""
}

{
  if (index($0, "\t") || index($0, "\r"))
    fail("tabs and carriage returns are not supported")
  if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^#/) next

  if ($0 == "components:") {
    if (section != "") fail("components must be the first section")
    section = "components"
    next
  }
  if ($0 == "profiles:") {
    if (section != "components") fail("profiles must follow components")
    section = "profiles"
    current_component = ""
    next
  }

  if ($0 ~ /^  [a-z][a-z0-9-]*:$/) {
    if (section != "components") fail("component outside components section")
    current_component = substr($0, 3, length($0) - 3)
    if (current_component in components) fail("duplicate component: " current_component)
    components[current_component] = 1
    component_order[++component_count] = current_component
    next
  }

  if ($0 ~ /^    summary: /) {
    if (section != "components" || current_component == "")
      fail("summary without a component")
    if (seen_property[current_component SUBSEP "summary"]++)
      fail("duplicate summary for component " current_component)
    value = substr($0, 14)
    if (value !~ /^[A-Za-z0-9][A-Za-z0-9 ,.\/()+_-]*$/ || value ~ / $/)
      fail("summary must be a plain one-line description")
    summaries[current_component] = value
    next
  }

  if ($0 ~ /^    (packages|tools): \[.*\]$/) {
    if (section != "components" || current_component == "")
      fail("component property without a component")
    line = substr($0, 5)
    colon = index(line, ":")
    key = substr(line, 1, colon - 1)
    if (seen_property[current_component SUBSEP key]++)
      fail("duplicate " key " for component " current_component)
    value = parse_list(substr(line, colon + 2), current_component "." key)
    if (key == "packages") packages[current_component] = value
    else tools[current_component] = value
    next
  }

  if ($0 ~ /^  [a-z][a-z0-9-]*: \[.*\]$/) {
    if (section != "profiles") fail("profile outside profiles section")
    line = substr($0, 3)
    colon = index(line, ":")
    name = substr(line, 1, colon - 1)
    if (name in profiles) fail("duplicate profile: " name)
    profiles[name] = parse_list(substr(line, colon + 2), "profile " name)
    profile_order[++profile_count] = name
    next
  }

  fail("unsupported profile syntax")
}

END {
  if (failed) exit 1
  if (section != "profiles" || component_count == 0 || profile_count == 0)
    fail("components and profiles are required")
  if (!("full" in profiles) || !("lite" in profiles))
    fail("full and lite profiles are required")

  for (i = 1; i <= profile_count; i++) {
    name = profile_order[i]
    if (profiles[name] == "") fail("empty profile: " name)
    count = split(profiles[name], members, " ")
    for (j = 1; j <= count; j++)
      if (!(members[j] in components)) fail("unknown component in " name ": " members[j])
  }

  count = split(catalog_tools, catalog_members, " ")
  for (i = 1; i <= count; i++) catalog_rank[catalog_members[i]] = i

  for (i = 1; i <= component_count; i++) {
    name = component_order[i]
    if (!(name in summaries)) fail("missing summary for component " name)
    if (packages[name] == "" && tools[name] == "") fail("empty component: " name)
    count = split(packages[name], members, " ")
    for (j = 1; j <= count; j++) {
      item = members[j]
      if (item == "") continue
      if (item in package_owner) fail("package " item " belongs to multiple components")
      package_owner[item] = name
    }
    count = split(tools[name], members, " ")
    for (j = 1; j <= count; j++) {
      item = members[j]
      if (item == "") continue
      tool_referenced[item] = 1
      if (item ~ /^npm:/ && (!index(" " tools[name] " ", " node ") || catalog_rank["node"] >= catalog_rank[item]))
        fail("npm tools require node before them in component " name)
      if (item ~ /^pipx:/ && (!index(" " tools[name] " ", " python ") ||
          !index(" " tools[name] " ", " aqua:astral-sh/uv ") ||
          catalog_rank["python"] >= catalog_rank[item] || catalog_rank["aqua:astral-sh/uv"] >= catalog_rank[item]))
        fail("pipx tools require python and uv before them in component " name)
    }
  }

  count = split(catalog_tools, catalog_members, " ")
  for (i = 1; i <= count; i++) catalog_has[catalog_members[i]] = 1
  for (item in tool_referenced)
    if (!(item in catalog_has)) fail("tool absent from catalog: " item)

  if (action == "validate") exit 0
  if (action == "profiles") {
    for (i = 1; i <= profile_count; i++) print profile_order[i]
    exit 0
  }
  if (action == "all-packages") { emit_members("packages", 1); exit 0 }
  if (action == "all-tools") { emit_members("tools", 1); exit 0 }

  if (action == "packs") {
    for (i = 1; i <= component_count; i++) {
      name = component_order[i]
      printf "%-12s %-14s %s\n", name, presets(name), summaries[name]
    }
    exit 0
  }
  if (action == "pack") {
    if (!(wanted_profile in components)) fail("unknown pack: " wanted_profile)
    name = wanted_profile
    print "pack: " name
    print "summary: " summaries[name]
    print "presets: " presets(name)
    selected[name] = 1
    printf "Stow packages: "; emit_members("packages", 0)
    printf "mise tools: "; emit_members("tools", 0)
    exit 0
  }

  if (!(wanted_profile in profiles)) fail("unknown profile: " wanted_profile)
  count = split(profiles[wanted_profile], members, " ")
  for (i = 1; i <= count; i++) add_selected(members[i])
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", addons)
  if (addons != "") {
    count = split(addons, members, /[[:space:]]+/)
    for (i = 1; i <= count; i++) add_selected(members[i])
  }

  if (action == "components") {
    for (i = 1; i <= selected_count; i++)
      printf "%s%s", (i == 1 ? "" : " "), selected_order[i]
    print ""
  } else if (action == "tool-users") {
    count = split(catalog_tools, catalog_members, " ")
    for (i = 1; i <= count; i++) {
      item = catalog_members[i]
      owners = ""
      owner_count = 0
      for (j = 1; j <= component_count; j++) {
        name = component_order[j]
        if (name in selected && index(" " tools[name] " ", " " item " ")) {
          owners = owners (owners == "" ? "" : " ") name
          owner_count++
        }
      }
      if (owner_count > 1) print item ": " owners
    }
  } else if (action == "packages" || action == "tools") {
    emit_members(action, 0)
  } else {
    fail("unknown profile action: " action)
  }
}
