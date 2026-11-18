# ARTEX detection-as-code starter

Seed of the CI pipeline: walk the ARTEX Sigma source tree, apply a **pySigma
processing-pipeline chain per target**, and emit SIEM-ready queries for both of
our SIEMs — Splunk (SPL) and Microsoft Sentinel (KQL) — under version control.

`sigma convert` alone emits correct *syntax* but *generic* field names. The
pipelines in `pipelines/*.yml` map Sigma fields/logsources onto the real schema
(Splunk CIM, Sentinel ASIM), so the output drops straight into a SIEM. The
pipelines are **code** and live next to the Sigma source.

## Layout
```
detection-as-code/
  Dockerfile          pinned sigma-cli toolchain (mirrors ARTEX's test pins)
  requirements.lock   exact sigma-cli + pySigma + 4 backend versions
  build.sh            the build (short bash loop over `sigma convert`)
  Makefile            make image | build | demo | clean
  pipelines/
    splunk_artex_house.yml          house CIM field map  (priority 30, after splunk_windows)
    sentinel_asim_artex_house.yml   house ASIM field map (priority 5,  before sentinel_asim)
  build/              generated (git-ignore): spl/ kql/ unsupported.txt
```
Sigma **source rules** live in `../detections/sigma/` (atomic `*.yml`) and
`../detections/sigma/correlation/` (correlation rules).

## Pipeline chains (one community base + one thin house pipeline per target)
| Target            | Backend | Community base   | House layer                      | Order |
|-------------------|---------|------------------|----------------------------------|-------|
| Splunk (SPL)      | splunk  | `splunk_windows` | `splunk_artex_house.yml`         | base → house (house pri 30) |
| Sentinel (KQL)    | kusto   | `sentinel_asim`  | `sentinel_asim_artex_house.yml`  | house → base (house pri 5)  |

* **Splunk house** runs *after* the community pipeline and renames leftover
  generic fields to CIM (`cs-user-agent`/`c-useragent` → `http_user_agent`,
  `TargetFilename` → `file_path`, `CommandLine` → `process`) and scopes
  web/proxy logsources to a sourcetype.
* **Sentinel house** runs *before* `sentinel_asim` (so ASIM's own field
  validation accepts the rule): it normalises `cs-user-agent` → `HttpUserAgent`
  and pins a `query_table` for the keyword-only application rule.

To emit Splunk `tstats` against a CIM data model instead of raw SPL, add
`-f data_model` to the splunk `sigma convert` call.

## Usage
```
make build     # -> build/spl/*.spl, build/kql/*.kql, build/unsupported.txt
make demo      # one rule, SPL + KQL side by side (DEMO_RULE=<name> to pick)
```

## Known routing (by design — ARTEX's own tests assert it)
A single Sigma detection converts to **both** Splunk and Kusto. A Sigma
**correlation** rule converts on Splunk but the Kusto backend **rejects** it:

```
Backend does not support correlation rules.
```

`build.sh` therefore converts the whole tree for Splunk (correlations included)
but feeds Kusto the atomic rules only, and lists every correlation rule in
`build/unsupported.txt` so an engineer **rebuilds it natively** as a Sentinel
scheduled/NRT KQL analytics rule. Correlations are routed, never silently
dropped.

## Pins
`requirements.lock` mirrors ARTEX's detection test suites: sigma-cli 3.1.0,
pySigma 1.5.1, backends splunk 2.1.0 / kusto 1.0.1 / elasticsearch 2.1.1 /
loki 0.15.1. Bump deliberately; re-run `make build` and the ARTEX suites
(`detections/tests/run-all.sh`) together.
