# artex-detection-as-code

Version-controlled **detection-as-code** for the ARTEX Sigma rules, targeting
**both** of our SIEMs:

- **Splunk** (SPL / savedsearches)
- **Microsoft Sentinel** (KQL / Kusto analytics rules)

`sigma convert` emits correct *syntax* but *generic* field names. This repo adds
a **pySigma processing-pipeline chain per target** so every query comes out with
real schema field names (Splunk CIM, Sentinel ASIM) — SIEM-ready and promotable
through CI.

## Layout
```
detection-as-code/      build tooling + house pipelines (see its README)
  Dockerfile            pinned sigma-cli toolchain (mirrors ARTEX test pins)
  requirements.lock     exact sigma-cli + pySigma + 4 backend versions
  build.sh              the build (short bash loop over `sigma convert`)
  Makefile              make image | build | demo | clean
  pipelines/            house pipelines (code, version-controlled)
detections/sigma/       Sigma SOURCE rules (atomic *.yml + correlation/)
LICENSE                 GNU AGPL-3.0
NOTICE                  ARTEX attribution + modification record
```

## Quick start
```bash
cd detection-as-code
make build     # -> build/spl/*.spl, build/kql/*.kql, build/unsupported.txt
make demo      # one rule, SPL + KQL side by side (DEMO_RULE=<name>)
```
Only host dependency is Docker. See `detection-as-code/README.md` for the
pipeline chains, pinned versions, and the correlation-routing rationale.

## Pipeline chains (one community base + one thin house pipeline per target)
| Target         | Backend | Community base   | House layer                                   |
|----------------|---------|------------------|-----------------------------------------------|
| Splunk (SPL)   | splunk  | `splunk_windows` | `pipelines/splunk_artex_house.yml`            |
| Sentinel (KQL) | kusto   | `sentinel_asim`  | `pipelines/sentinel_asim_artex_house.yml`     |

## Known routing (by design)
A single Sigma detection converts to **both** Splunk and Kusto. A Sigma
**correlation** rule converts on Splunk but Kusto rejects it
(`Backend does not support correlation rules.`). The build lists those in
`build/unsupported.txt` so they are **rebuilt natively** as Sentinel
scheduled/NRT KQL analytics rules — never silently dropped.

## License
AGPL-3.0. The `detections/sigma/` rules are derived from ARTEX
(Autumn-27/ARTEX via jiwoochris/artex-global, AGPL-3.0); see `NOTICE`.
