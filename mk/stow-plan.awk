# GNU Stow's restow preview unlinks and relinks every existing managed file.
# The "reverts previous action" marker means that the link ends unchanged.
/^UNLINK: / {
  path = substr($0, length("UNLINK: ") + 1)
  unlink_line[path] = NR
}

/^LINK: .* \(reverts previous action\)$/ {
  path = substr($0, length("LINK: ") + 1)
  sub(/ => .*/, "", path)
  if (path in unlink_line) {
    omit[unlink_line[path]] = 1
    omit[NR] = 1
    delete unlink_line[path]
  }
}

{ line[NR] = $0 }

END {
  for (i = 1; i <= NR; i++) {
    if (omit[i] || line[i] == "WARNING: in simulation mode so not modifying filesystem.")
      continue
    if (line[i] == "")
      continue
    print line[i]
    shown = 1
  }
  if (!shown)
    print "no Stow link changes"
}
