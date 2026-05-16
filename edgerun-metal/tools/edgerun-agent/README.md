# EdgeRun Agent service tooling

This tool provides an always-on local agent that:

- pulls `main` from GitHub on a timer
- runs `.edgerun/agent/run.sh`
- collects diagnostics/output into `agent-output/latest`
- commits outputs to `agent/fw`
- pushes the output branch without touching `main`

## Install

```bash
sudo ./tools/edgerun-agent/install-agent-service.sh
```

This creates `/etc/edgerun-agent.env` if missing, installs:

- `systemd/edgerun-agent.service`
- `systemd/edgerun-agent.timer`
- `systemd/edgerun-agent.env.example`

Then runs:

- `systemctl start edgerun-agent.service`
- prints service status and latest logs

## Run once

```bash
sudo systemctl start edgerun-agent.service
```

## Monitor

```bash
journalctl -u edgerun-agent.service -f
```

## Environment

- `EDGERUN_AGENT_REPO=/home/ken/edgerun-c/edgerun-metal`
- `EDGERUN_AGENT_REMOTE=origin`
- `EDGERUN_AGENT_SOURCE_BRANCH=main`
- `EDGERUN_AGENT_OUTPUT_BRANCH=agent/fw`
- `EDGERUN_AGENT_HOSTNAME=fw`
- `EDGERUN_AGENT_INTERVAL_SEC=60`
- `EDGERUN_AGENT_RUN_SCRIPT=.edgerun/agent/run.sh`
