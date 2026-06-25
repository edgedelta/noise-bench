FROM python:3.12-slim

# Lightweight CLI tooling so the agent can grep/query the telemetry by hand.
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq curl ca-certificates less vim grep coreutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workdir

# Copy the frozen telemetry window for this scenario into /workdir.
# NOTE: ground-truth labels live under tests/ and are NOT copied here.
COPY workdir/ /workdir/

CMD ["/bin/bash"]
