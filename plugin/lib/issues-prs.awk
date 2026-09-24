# Open pull requests -> the issues they close, as Belfry reads them: a body saying
# "Fixes #12" (or close, closes, closed, fix, fixed, resolve, resolves, resolved).
#
#   awk -F '\t' -f issues-lib.awk -f issues-prs.awk PRS
#
# PRS holds "number<TAB>url<TAB>draft<TAB>body" per pull request, body with @tsv's
# escapes, newest first. Out comes "issue<TAB>#number<TAB>url<TAB>draft", the first pull
# request for each issue.

{
  s = tolower(tsv_unescape($4))
  while (match(s, /(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)[ \t\r\n]+#[0-9]+/)) {
    pre = RSTART > 1 ? substr(s, RSTART - 1, 1) : ""
    m = substr(s, RSTART, RLENGTH)
    post = substr(s, RSTART + RLENGTH, 1)
    s = substr(s, RSTART + RLENGTH)
    if (pre ~ /[a-z0-9_]/ || post ~ /[a-z0-9_]/) continue
    sub(/^[^#]*#/, "", m)
    m += 0
    if (!(m in pr)) { pr[m] = $1; print m "\t#" $1 "\t" $2 "\t" $3 }
  }
}
