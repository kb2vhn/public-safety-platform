#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
deployment_root="$module_root/deployment"
units_root="$deployment_root/systemd"
sysusers_file="$deployment_root/sysusers.d/iron-signal-platform.conf"

pass_count=0
pass() {
    pass_count=$((pass_count + 1))
    printf 'PASS: %s\n' "$1"
}
fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for command_name in \
    go systemd-analyze systemd-sysusers grep find sort sed mktemp sha256sum awk
do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "Required process-host command available: $command_name"
    pass "Required process-host command available: $command_name"
done

systemd_version="$(systemd-analyze --version | awk 'NR == 1 {print $2}')"
[[ "$systemd_version" =~ ^[0-9]+$ ]] \
    || fail "systemd version is numeric"
(( systemd_version >= 261 )) \
    || fail "systemd version is at least 261"
pass "Canonical systemd feature baseline is at least 261"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'

go test -race ./internal/processhost ./internal/bootstrap
pass "Process-host and bootstrap race tests pass"

[[ -f "$sysusers_file" ]] || fail "Service sysusers file exists"
systemd-sysusers --dry-run "$sysusers_file" >/dev/null
pass "Service sysusers file parses in dry-run mode"

mapfile -t units < <(
    find "$units_root" -maxdepth 1 -type f -name '*.service' -printf '%f\n' |
        sort
)
expected_units=(
    iron-signal-foundation-api.service
    iron-signal-integration-delivery-worker.service
    iron-signal-monitoring-delivery-worker.service
)
[[ "${units[*]}" == "${expected_units[*]}" ]] \
    || fail "Exact three service-unit inventory"
pass "Exact three service-unit inventory"

if find "$deployment_root" -type f -name '*.socket' -print -quit |
    grep -q .
then
    fail "Socket activation remains absent"
fi
pass "Socket activation remains absent"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step4-host.XXXXXX")"
cleanup() {
    rm -rf -- "$scratch"
}
trap cleanup EXIT

"$script_dir/build.sh" "$scratch/build" >/dev/null
pass "Step 4 candidate binaries build reproducibly"

declare -A expected_user=(
    [iron-signal-foundation-api.service]=issp-foundation-api
    [iron-signal-integration-delivery-worker.service]=issp-integration-delivery
    [iron-signal-monitoring-delivery-worker.service]=issp-monitoring-delivery
)
declare -A expected_binary=(
    [iron-signal-foundation-api.service]=foundation-api
    [iron-signal-integration-delivery-worker.service]=integration-delivery-worker
    [iron-signal-monitoring-delivery-worker.service]=monitoring-delivery-worker
)
declare -A expected_credential=(
    [iron-signal-foundation-api.service]=foundation-api.database-url.cred
    [iron-signal-integration-delivery-worker.service]=integration-delivery-worker.database-url.cred
    [iron-signal-monitoring-delivery-worker.service]=monitoring-delivery-worker.database-url.cred
)
declare -A expected_port=(
    [iron-signal-foundation-api.service]=18081
    [iron-signal-integration-delivery-worker.service]=18082
    [iron-signal-monitoring-delivery-worker.service]=18083
)

required_lines=(
    'Type=notify'
    'NotifyAccess=main'
    'Restart=on-failure'
    'RestartSec=5s'
    'RestartPreventExitStatus=78'
    'TimeoutStartSec=30s'
    'TimeoutStopSec=20s'
    'WatchdogSec=30s'
    'NoNewPrivileges=yes'
    'CapabilityBoundingSet='
    'AmbientCapabilities='
    'PrivateTmp=yes'
    'PrivateDevices=yes'
    'PrivateMounts=yes'
    'ProtectSystem=strict'
    'ProtectHome=yes'
    'ProtectKernelTunables=yes'
    'ProtectKernelModules=yes'
    'ProtectKernelLogs=yes'
    'ProtectControlGroups=yes'
    'ProtectClock=yes'
    'ProtectHostname=yes'
    'ProtectProc=invisible'
    'ProcSubset=pid'
    'RestrictNamespaces=yes'
    'RestrictRealtime=yes'
    'RestrictSUIDSGID=yes'
    'LockPersonality=yes'
    'MemoryDenyWriteExecute=yes'
    'SystemCallArchitectures=native'
    'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6'
    'RemoveIPC=yes'
    'KeyringMode=private'
    'InaccessiblePaths=/etc/iron-signal-platform/credentials'
    'LimitNOFILE=1024'
    'TasksMax=64'
    'MemoryHigh=192M'
    'MemoryMax=256M'
)

for unit_name in "${expected_units[@]}"; do
    unit="$units_root/$unit_name"
    user="${expected_user[$unit_name]}"
    binary="${expected_binary[$unit_name]}"
    credential="${expected_credential[$unit_name]}"
    port="${expected_port[$unit_name]}"

    grep -Fxq "User=$user" "$unit" \
        || fail "$unit_name exact service user"
    grep -Fxq "Group=$user" "$unit" \
        || fail "$unit_name exact service group"
    grep -Fxq "ExecStart=/usr/lib/iron-signal-platform/$binary" "$unit" \
        || fail "$unit_name direct executable"
    grep -Fxq \
        "LoadCredentialEncrypted=database-url:/etc/iron-signal-platform/credentials/$credential" \
        "$unit" || fail "$unit_name exact encrypted credential source"
    grep -Fxq "Environment=ISSP_ADMIN_LISTEN_ADDRESS=127.0.0.1:$port" "$unit" \
        || fail "$unit_name exact loopback administrative port"
    grep -Fxq 'Environment=ISSP_DATABASE_DSN_FILE=%d/database-url' "$unit" \
        || fail "$unit_name credential-directory DSN reference"

    for required_line in "${required_lines[@]}"; do
        grep -Fxq "$required_line" "$unit" \
            || fail "$unit_name contains $required_line"
    done

    if grep -Eq \
        '^(DynamicUser|EnvironmentFile|RootDirectory|RootImage|PrivateNetwork)=' \
        "$unit"
    then
        fail "$unit_name contains no unaccepted host expansion"
    fi

    if grep -E '^ExecStart=.*(sh|bash|env)[[:space:]]' "$unit" >/dev/null
    then
        fail "$unit_name does not use a shell wrapper"
    fi

    verified_unit="$scratch/$unit_name"
    sed \
        "s#^ExecStart=/usr/lib/iron-signal-platform/$binary\$#ExecStart=$scratch/build/bin/$binary#" \
        "$unit" >"$verified_unit"

    systemd-analyze verify "$verified_unit" >/dev/null
    pass "$unit_name passes systemd-analyze verify"

    systemd-analyze security \
        --offline=yes \
        --no-pager \
        "$verified_unit" >"$scratch/$unit_name.security"
    grep -Fq 'Overall exposure level' "$scratch/$unit_name.security" \
        || fail "$unit_name security analysis produced an exposure result"
    pass "$unit_name produces offline security analysis"
done

users="$(
    awk '$1 == "u" {print $2}' "$sysusers_file" |
        sort
)"
expected_users="$(
    printf '%s\n' \
        issp-foundation-api \
        issp-integration-delivery \
        issp-monitoring-delivery |
        sort
)"
[[ "$users" == "$expected_users" ]] \
    || fail "Exact three distinct non-login service users"
pass "Exact three distinct non-login service users"

if grep -R -Eiq \
    'postgres(ql)?://|password=|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' \
    "$deployment_root"
then
    fail "Deployment files contain no credential material"
fi
pass "Deployment files contain no credential material"

printf '\nPhase 6 Step 4 process-host static validation: %d PASS, 0 FAIL\n' \
    "$pass_count"
