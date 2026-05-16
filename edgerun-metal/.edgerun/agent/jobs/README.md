# Repo-driven edgerun-agent jobs

The agent loads the current job from:

- `.edgerun/agent/jobs/current.env`

Only a strict, limited key/value format is supported.

## Allowed keys

- `JOB_ID`
- `ACTION`
- `NETBOOT_IFACE`
- `NETBOOT_MODE`
- `NETBOOT_ALLOW_MAC`
- `NETBOOT_MGMT_DHCP`
- `NETBOOT_MGMT_MAC`
- `NETBOOT_MGMT_IP`
- `NETBOOT_CLIENT_IP`
- `NETBOOT_HTTP_PORT`
- `NETBOOT_FORCE_HTTP_FOR_PXE`
- `NETBOOT_EFI`

Unknown keys are ignored.

## Allowed actions

- `noop`
- `collect`
- `build`
- `build-netboot`
- `restart-netboot`
- `set-netboot-env`
- `http-self-test`
- `status`

Each successfully completed job is marked done in:

- `~/.local/state/edgerun-agent/jobs/<JOB_ID>.done`

Completed jobs are not re-run. Failed jobs stay pending and can retry next cycle.

### Security notes

- Values are validated to reject shell metacharacters.
- No `eval` or arbitrary script execution is performed.
- `set-netboot-env` only writes known environment keys to `/etc/edgerun-netboot.env`.
