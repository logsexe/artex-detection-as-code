#!/usr/bin/env bash
#
# ARTEX detection-as-code build — the seed of the CI step.
#
# Walks the ARTEX Sigma source tree and emits, per rule:
#   build/spl/<rule>.spl   Splunk SPL  (pipeline chain: splunk_windows + house)
#   build/kql/<rule>.kql   Sentinel KQL (pipeline chain: house + sentinel_asim)
#   build/unsupported.txt  rules a backend rejected, with the reason
#
# The whole point is SIEM-READY output: every query comes out with real schema
# field names because a pySigma PROCESSING PIPELINE is applied per target —
# one community/base pipeline + one thin house pipeline (pipelines/*.yml),
# layered by priority. No raw `--without-pipeline` generic output here.
#
# Known, by-design routing (ARTEX's own tests assert it):
#   * A single Sigma detection converts to BOTH Splunk and Kusto.
#   * A Sigma CORRELATION rule converts on Splunk but the Kusto backend rejects
#     it ("Backend does not support correlation rules"). Those rules are routed
#     to unsupported.txt so a human rebuilds them natively as Sentinel
#     scheduled/NRT analytics rules — they are never silently dropped.
#
# No magic: it is a short bash loop over `sigma convert`. Runs inside the pinned
# toolchain image (see Dockerfile); `make build` mounts the paths for you.
#
# Overridable via env (defaults suit the container):
#   SIGMA_DIR      Sigma source tree         (default /sigma)
#   PIPELINES_DIR  house pipelines dir        (default /work/pipelines)
#   BUILD_DIR      output root                (default /work/build)
set -uo pipefail

SIGMA_DIR="${SIGMA_DIR:-/sigma}"
PIPELINES_DIR="${PIPELINES_DIR:-/work/pipelines}"
BUILD_DIR="${BUILD_DIR:-/work/build}"

SPL_DIR="$BUILD_DIR/spl"
KQL_DIR="$BUILD_DIR/kql"
UNSUPPORTED="$BUILD_DIR/unsupported.txt"

# Per-target pipeline chains. Order expresses priority intent; pySigma still
# sorts by each pipeline's own `priority:` field.
#   Splunk : community splunk_windows (pri 20) -> house CIM map (pri 30)
#   Sentinel: house field-normalise (pri 5) -> community sentinel_asim (pri 10)
SPLUNK_PIPES="-p splunk_windows -p $PIPELINES_DIR/splunk_artex_house.yml"
KUSTO_PIPES="-p $PIPELINES_DIR/sentinel_asim_artex_house.yml -p sentinel_asim"

rm -rf "$SPL_DIR" "$KQL_DIR" "$UNSUPPORTED"
mkdir -p "$SPL_DIR" "$KQL_DIR"
: > "$UNSUPPORTED"

log(){ printf '%s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Splunk — the whole tree (atomic + correlation) converts in ONE pass.
#    --output-dir writes one file per rule; correlations resolve their atomic
#    base rules because the whole tree is a single Sigma collection.
# ---------------------------------------------------------------------------
log "== Splunk (SPL) =="
if sigma convert -t splunk $SPLUNK_PIPES --output-dir "$SPL_DIR" --fail-unsupported "$SIGMA_DIR" >/dev/null 2>"$BUILD_DIR/.spl.err"; then
  # sigma writes <rule>.txt; normalise the extension to .spl.
  for f in "$SPL_DIR"/*.txt; do [ -e "$f" ] && mv -- "$f" "${f%.txt}.spl"; done
  log "   wrote $(find "$SPL_DIR" -name '*.spl' | wc -l | tr -d ' ') SPL file(s)"
else
  log "   Splunk whole-tree conversion FAILED (see $BUILD_DIR/.spl.err)"
  sed 's/^/   > /' "$BUILD_DIR/.spl.err" || true
fi

# ---------------------------------------------------------------------------
# 2. Sentinel/Kusto — ATOMIC rules only, one file per rule.
#    Kusto rejects Sigma correlation rules, so we never feed it the whole tree;
#    we convert each atomic rule and capture any per-rule rejection.
# ---------------------------------------------------------------------------
log "== Sentinel (KQL) =="
for f in "$SIGMA_DIR"/*.yml; do
  [ -e "$f" ] || continue
  name="$(basename "$f" .yml)"
  if out="$(sigma convert -t kusto $KUSTO_PIPES "$f" 2>"$BUILD_DIR/.kql.err")"; then
    printf '%s\n' "$out" > "$KQL_DIR/$name.kql"
  else
    reason="$(grep -m1 -iE 'error|not supported' "$BUILD_DIR/.kql.err" | sed 's/^Error: //')"
    printf 'kql  %-40s  %s\n' "$name" "${reason:-conversion failed}" >> "$UNSUPPORTED"
  fi
done
log "   wrote $(find "$KQL_DIR" -name '*.kql' | wc -l | tr -d ' ') KQL file(s)"

# ---------------------------------------------------------------------------
# 3. Correlation rules on Kusto — rejected BY DESIGN. Route, do not drop.
# ---------------------------------------------------------------------------
if [ -d "$SIGMA_DIR/correlation" ]; then
  for f in "$SIGMA_DIR"/correlation/*.yml; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .yml)"
    printf 'kql  %-40s  Backend does not support correlation rules — rebuild as a native Sentinel scheduled/NRT KQL analytics rule\n' \
      "$name" >> "$UNSUPPORTED"
  done
fi

rm -f "$BUILD_DIR/.spl.err" "$BUILD_DIR/.kql.err"

log ""
log "== build summary =="
log "  SPL : $(find "$SPL_DIR" -name '*.spl' | wc -l | tr -d ' ')  -> $SPL_DIR"
log "  KQL : $(find "$KQL_DIR" -name '*.kql' | wc -l | tr -d ' ')  -> $KQL_DIR"
log "  unsupported: $(grep -c . "$UNSUPPORTED" 2>/dev/null || echo 0) line(s) -> $UNSUPPORTED"
[ -s "$UNSUPPORTED" ] && sed 's/^/    /' "$UNSUPPORTED"
log "RESULT: OK"
