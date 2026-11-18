# Pinned sigma-cli toolchain for the ARTEX detection-as-code pipeline.
# Versions mirror ARTEX's own detection test suites (detections/tests/*):
#   sigma-cli 3.1.0, pySigma 1.5.1, and the four backends ARTEX wires in.
# Pinning every version keeps CI reproducible — the same Sigma source always
# compiles to the same SPL and KQL.
FROM python:3.12-slim

# Pin exactly (see requirements.lock). Installing the backend packages directly
# (instead of `sigma plugin install`, which floats to latest) is what makes the
# build reproducible. sigma-cli auto-discovers the backends via entry points.
COPY requirements.lock /tmp/requirements.lock
RUN pip install --no-cache-dir --disable-pip-version-check -r /tmp/requirements.lock

WORKDIR /work
COPY build.sh /usr/local/bin/artex-dac-build
RUN chmod +x /usr/local/bin/artex-dac-build

ENTRYPOINT ["/usr/local/bin/artex-dac-build"]
