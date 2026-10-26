#!/usr/bin/env python3
"""
Parses Get-HostBaseline CSV output folders and ships telemetry to Elastic Stack / Security Onion.
Zero external dependencies (Python 3 standard library only).
"""

import argparse
import base64
import csv
import json
import os
import ssl
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

HUNT_METADATA = {
    "osinfo": ("os_release.name+os_release.version+os_release.manufacturer+os_release.serial_number", ["os_release.name"]),
    "processes": ("process.grandparent.name+process.parent.name+process.name+process.path+process.command_line", ["process.name", "process.path"]),
    "services": ("service.name+service.display_name+service.state+service.start_mode", ["service.name", "service.state"]),
    "network": ("connection.process_name+connection.local_address+connection.local_port+connection.remote_address+connection.remote_port+connection.state", ["connection.process_name", "connection.remote_address"]),
    "shares": ("share.name+share.account+share.control+share.right", ["share.name"]),
    "registryrunkeys": ("registry.key+registry.value_name+registry.value_data", ["registry.value_name"]),
    "startup": ("startup_file.name+startup_file.path+startup_file.description", ["startup_file.name"]),
    "tasks": ("task.name+task.path+task.state+task.uri", ["task.name", "task.path"]),
    "logon": ("logon.user+logon.type+logon.start_time+logon.domain", ["logon.user", "logon.type"]),
    "groupmembers": ("group.name+group.member", ["group.name", "group.member"]),
    "registryshellfolders": ("shell_folder.key+shell_folder.value_name+shell_folder.value_data", ["shell_folder.value_name"]),
    "prefetch": ("prefetch.process_name+prefetch.path+prefetch.created+prefetch.modified", ["prefetch.process_name"]),
}


def g(row: dict, key: str, default: str = "") -> str:
    val = row.get(key)
    return str(val).strip() if val is not None and str(val).strip() != "" else default


def resolve_timestamp(row: dict, force_ingest: bool) -> str:
    now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
    if force_ingest or not row:
        return now_utc
    for col in ("UTCTime", "Time", "LastWriteTimeUTC", "CreationTimeUtc"):
        raw = g(row, col)
        if raw:
            try:
                norm = raw.replace("Z", "+00:00")
                # Truncate 7-digit .NET ticks to 6-digit microseconds for Python fromisoformat
                if "." in norm:
                    head, tail = norm.split(".", 1)
                    tz_part = ""
                    for sep in ("+", "-"):
                        if sep in tail:
                            frac, tz_rest = tail.split(sep, 1)
                            tz_part = sep + tz_rest
                            tail = frac
                            break
                    norm = f"{head}.{tail[:6]}{tz_part}"
                dt = datetime.fromisoformat(norm).astimezone(timezone.utc)
                return dt.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
            except Exception:
                continue
    return now_utc


def convert_row(csv_name: str, row: dict, host_name: str, prefix: str, module: str, force_ingest: bool):
    ts = resolve_timestamp(row, force_ingest)
    resolved_host = g(row, "CSName", g(row, "PSComputerName", host_name))

    if csv_name == "OSInfo":
        os_name, os_ver = g(row, "OperatingSystem"), g(row, "OperatingSystemVersion")
        return "osinfo", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"OS Information: {os_name} ({os_ver})",
            "event": {"dataset": f"{prefix}.osinfo", "module": module},
            "os_release": {
                "cs_name": g(row, "CSName"),
                "name": os_name,
                "version": os_ver,
                "manufacturer": g(row, "Manufacturer"),
                "registered_owner": g(row, "RegisteredOwner"),
                "install_date": g(row, "InstallDate"),
                "last_boot_time": g(row, "LastBootTime"),
                "serial_number": g(row, "SerialNumber"),
                "time": g(row, "Time"),
                "utc_time": g(row, "UTCTime"),
            },
        }
    if csv_name == "Processes":
        p_name, proc_id = g(row, "ProcessName", "unknown"), g(row, "ProcessID", "unknown")
        return "processes", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"Process: {p_name} (PID: {proc_id})",
            "event": {"dataset": f"{prefix}.processes", "module": module},
            "process": {
                "name": g(row, "ProcessName"),
                "pid": g(row, "ProcessID"),
                "parent": {"pid": g(row, "ParentProcessID"), "name": g(row, "ParentProcessName")},
                "grandparent": {"pid": g(row, "GrandParentProcessID"), "name": g(row, "GrandParentProcessName")},
                "path": g(row, "Path"),
                "command_line": g(row, "CommandLine"),
                "handle_count": g(row, "HandleCount"),
                "thread_count": g(row, "ThreadCount"),
                "ps_computer_name": g(row, "PSComputerName"),
                "runspace_id": g(row, "RunspaceId"),
                "ps_show_computer_name": g(row, "PSShowComputerName"),
                "lineage_hash": g(row, "LineageHash"),
            },
        }
    if csv_name == "Services":
        s_name, s_state = g(row, "ServiceName", "unknown"), g(row, "ServiceState", "unknown")
        return "services", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"Service: {s_name} (State: {s_state})",
            "event": {"dataset": f"{prefix}.services", "module": module},
            "service": {
                "name": g(row, "ServiceName"),
                "state": g(row, "ServiceState"),
                "display_name": g(row, "ServiceDisplayName"),
                "description": g(row, "ServiceDescription"),
                "path": g(row, "PathName"),
                "start_mode": g(row, "StartMode"),
                "pid": g(row, "ProcessId"),
                "process_name": g(row, "ProcessName"),
                "parent_pid": g(row, "ParentProcessID"),
                "parent_process_name": g(row, "ParentProcessName"),
                "system_name": g(row, "SystemName"),
                "install_date": g(row, "InstallDate"),
                "exit_code": g(row, "ExitCode"),
                "delayed_auto_start": g(row, "DelayedAutoStart"),
            },
        }
    if csv_name == "Connections":
        la, lp, ra, rp, st = g(row, "LocalAddress"), g(row, "LocalPort"), g(row, "RemoteAddress"), g(row, "RemotePort"), g(row, "State")
        return "network", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"Connection: {la}:{lp} -> {ra}:{rp} ({st})",
            "event": {"dataset": f"{prefix}.network", "module": module},
            "connection": {
                "local_address": la,
                "local_port": lp,
                "remote_address": ra,
                "remote_port": rp,
                "state": st,
                "pid": g(row, "OwningProcess"),
                "process_name": g(row, "ProcessName"),
                "parent_pid": g(row, "ParentProcessID"),
                "parent_process": g(row, "ParentProcess"),
                "creation_time": g(row, "CreationTime"),
            },
        }
    if csv_name == "Shares":
        sh_name = g(row, "Name")
        return "shares", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"SMB Share: {sh_name}",
            "event": {"dataset": f"{prefix}.shares", "module": module},
            "share": {
                "name": sh_name,
                "account": g(row, "AccountName"),
                "control": g(row, "AccessControlType"),
                "right": g(row, "AccessRight"),
            },
        }
    if csv_name == "RegistryRun":
        k_name, v_name, details = g(row, "KeyName"), g(row, "ValueName"), g(row, "Details")
        return "registryrunkeys", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"Registry Run: [{k_name}] {v_name} = {details}",
            "event": {"dataset": f"{prefix}.registryrunkeys", "module": module},
            "registry": {
                "key": k_name,
                "value_name": v_name,
                "value_data": details,
                "process_name": g(row, "ProcessName"),
                "time": g(row, "Time"),
            },
        }
    if csv_name == "StartupFolders":
        desc, f_name = g(row, "StartupFolderDescription"), g(row, "FileInfoName")
        return "startup", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"Startup File: [{desc}] {f_name}",
            "event": {"dataset": f"{prefix}.startup", "module": module},
            "startup_file": {
                "path": g(row, "StartupFolderPath"),
                "description": desc,
                "name": f_name,
                "size": g(row, "FileInfoSize"),
                "modified": g(row, "LastWriteTime"),
                "modified_utc": g(row, "LastWriteTimeUTC"),
                "hash": g(row, "Hash"),
            },
        }
    if csv_name == "ScheduledTasks":
        t_name = g(row, "TaskName", "unknown")
        return "tasks", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"Scheduled Task: {t_name}",
            "event": {"dataset": f"{prefix}.tasks", "module": module},
            "task": {
                "name": g(row, "TaskName"),
                "author": g(row, "Author"),
                "date": g(row, "Date"),
                "uri": g(row, "URI"),
                "state": g(row, "State"),
                "path": g(row, "TaskPath"),
                "last_run": g(row, "LastRunTime"),
                "last_run_utc": g(row, "LastRunTimeUTC"),
                "last_result": g(row, "LastTaskResult"),
                "next_run": g(row, "NextRunTime"),
            },
        }
    if csv_name == "LogonHistory":
        lu, ld, lid, lt = g(row, "LogonUser", "unknown"), g(row, "LogonDomain", "unknown"), g(row, "LogonId", "unknown"), g(row, "LogonType", "unknown")
        return "logon", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"Logon: {lu} (Domain: {ld}, ID: {lid}, Type: {lt})",
            "event": {"dataset": f"{prefix}.logon", "module": module},
            "logon": {
                "id": g(row, "LogonId"),
                "type_id": g(row, "LogonTypeId"),
                "type": g(row, "LogonType"),
                "domain": g(row, "LogonDomain"),
                "user": g(row, "LogonUser"),
                "start_time": g(row, "StartTime"),
                "start_time_utc": g(row, "StartTimeUTC"),
            },
        }
    if csv_name == "LocalGroupMembers":
        g_name = g(row, "GroupName")
        raw_members = g(row, "Member")
        members = [m.strip() for m in raw_members.split(",") if m.strip()] if raw_members else []
        return "groupmembers", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"Local Group Member: {g_name}",
            "event": {"dataset": f"{prefix}.groupmembers", "module": module},
            "group": {"name": g_name, "member": members},
        }
    if csv_name == "RegistryUserShellFolders":
        vn, vd = g(row, "ValueName"), g(row, "ValueData")
        return "registryshellfolders", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"User Shell Folder: {vn} = {vd}",
            "event": {"dataset": f"{prefix}.registryshellfolders", "module": module},
            "shell_folder": {
                "key": g(row, "Key"),
                "value_name": vn,
                "value_data": vd,
                "time": g(row, "Time"),
            },
        }
    if csv_name == "Prefetches":
        full_name = g(row, "FullName")
        if not full_name:
            return None, None
        return "prefetch", {
            "hostname": resolved_host,
            "@timestamp": ts,
            "message": f"Prefetch file: {full_name}",
            "event": {"dataset": f"{prefix}.prefetch", "module": module},
            "prefetch": {
                "path": full_name,
                "created": g(row, "CreationTimeUtc"),
                "accessed": g(row, "LastAccessTimeUtc"),
                "modified": g(row, "LastWriteTimeUtc"),
                "process_name": g(row, "ProcessName"),
            },
        }
    return None, None


def load_dotenv(env_file: str = "") -> dict:
    script_dir = Path(__file__).resolve().parent
    candidates = [Path(env_file)] if env_file else [script_dir / ".env", script_dir.parent / ".env"]
    config = {}
    for path in candidates:
        if path and path.is_file():
            for line in path.read_text(encoding="utf-8").splitlines():
                s = line.strip()
                if s and not s.startswith("#") and "=" in s:
                    k, v = s.split("=", 1)
                    k, v = k.strip(), v.strip()
                    if len(v) >= 2 and ((v[0] == '"' and v[-1] == '"') or (v[0] == "'" and v[-1] == "'")):
                        v = v[1:-1]
                    config[k] = v
            break
    return config


def post_json(url: str, body: bytes, content_type: str, headers: dict, ssl_ctx: ssl.SSLContext):
    req_headers = {**headers, "Content-Type": content_type}
    req = urllib.request.Request(url, data=body, headers=req_headers, method="POST")
    with urllib.request.urlopen(req, context=ssl_ctx, timeout=30) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        return json.loads(raw) if raw else {}


def run_selftest(prefix: str, module: str) -> None:
    samples = {
        "OSInfo": {"CSName": "SRV01", "OperatingSystem": "Windows Server 2022", "OperatingSystemVersion": "10.0.20348", "UTCTime": "2026-10-26T10:00:00.1234567Z"},
        "Processes": {"CSName": "SRV01", "ProcessName": "powershell.exe", "ProcessID": "1234"},
        "Services": {"CSName": "SRV01", "ServiceName": "WinRM", "ServiceState": "Running"},
        "Connections": {"CSName": "SRV01", "LocalAddress": "10.0.0.5", "LocalPort": "5985", "RemoteAddress": "10.0.0.1", "RemotePort": "51234", "State": "Established"},
        "Shares": {"Name": "C$", "AccountName": "BUILTIN\\Administrators", "AccessControlType": "Allow", "AccessRight": "Full"},
        "RegistryRun": {"KeyName": "Run", "Details": "C:\\app.exe", "ProcessName": "app"},
        "StartupFolders": {"CSName": "SRV01", "StartupFolderPath": "C:\\Startup", "StartupFolderDescription": "All Users", "FileInfoName": "autorun.lnk"},
        "ScheduledTasks": {"CSName": "SRV01", "TaskName": "Updater", "State": "Ready"},
        "LogonHistory": {"CSName": "SRV01", "LogonId": "999", "LogonType": "Network", "LogonUser": "admin"},
        "LocalGroupMembers": {"CSName": "SRV01", "GroupName": "Administrators", "Member": "CORP\\Domain Admins, SRV01\\Administrator"},
        "RegistryUserShellFolders": {"Key": "Shell Folders", "ValueName": "Startup", "ValueData": "C:\\Startup"},
        "Prefetches": {"CSName": "SRV01", "FullName": "C:\\Windows\\Prefetch\\CMD.EXE-123.pf", "ProcessName": "CMD.EXE"},
    }
    with tempfile.TemporaryDirectory() as tmp:
        host_dir = Path(tmp) / "SRV01"
        host_dir.mkdir(parents=True, exist_ok=True)
        for name, sample in samples.items():
            csv_path = host_dir / f"{name}.csv"
            with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
                w = csv.DictWriter(f, fieldnames=list(sample.keys()))
                w.writeheader()
                w.writerow(sample)
            with csv_path.open("r", newline="", encoding="utf-8-sig") as f:
                rows = list(csv.DictReader(f))
            suf, doc = convert_row(name, rows[0], "SRV01", prefix, module, False)
            assert suf and doc and doc["hostname"] == "SRV01" and doc["event"]["dataset"] == f"{prefix}.{suf}", f"Failed {name}"
            assert "@timestamp" in json.dumps(doc), f"Missing @timestamp in {name}"
    suf, doc = convert_row("Prefetches", {"Length": "34"}, "SRV01", prefix, module, False)
    assert suf is None and doc is None, "Disabled prefetch row was not skipped"
    print("[OK] All 12 Get-HostBaseline dataset parsers and CSV round-trips passed self-test.")


def main():
    parser = argparse.ArgumentParser(description="Ship Get-HostBaseline CSV folders to Elastic Stack / Security Onion.")
    parser.add_argument("baseline_path_pos", nargs="?", default="", help="Path to baseline folder (optional positional)")
    parser.add_argument("-p", "--baseline-path", default="", help="Path to Output/Baselines, a HostBaselines_* folder, or a host folder")
    parser.add_argument("-a", "--all", action="store_true", help="Ship all baseline runs inside Output/Baselines")
    parser.add_argument("-u", "--elastic-url", default="", help="Elasticsearch URL (e.g. https://10.0.0.10:9200)")
    parser.add_argument("--user", default="", help="Elasticsearch username")
    parser.add_argument("--password", default="", help="Elasticsearch password")
    parser.add_argument("--so-url", default="", help="Security Onion base URL for Hunt links")
    parser.add_argument("--env-file", default="", help="Path to .env file")
    parser.add_argument("--dataset-prefix", default="admintool.windows", help="Dataset prefix (default: admintool.windows)")
    parser.add_argument("--module-name", default="admintool", help="Module name (default: admintool)")
    parser.add_argument("--batch-size", type=int, default=500, help="Bulk API batch size (default: 500)")
    parser.add_argument("--single-doc", action="store_true", help="POST row-by-row to /_doc instead of _bulk")
    parser.add_argument("--ingest-timestamp", action="store_true", help="Use current UTC time instead of CSV timestamp")
    parser.add_argument("-l", "--links-file", default="", help="Output file path for Security Onion Hunt links (.txt)")
    parser.add_argument("--dry-run", action="store_true", help="Parse CSVs and write Hunt links without sending HTTP requests")
    parser.add_argument("--self-test", action="store_true", help="Run built-in parser self-test")
    args = parser.parse_args()

    if args.self_test:
        run_selftest(args.dataset_prefix, args.module_name)
        return

    env_cfg = load_dotenv(args.env_file)
    es_url = (args.elastic_url or os.environ.get("ES_URL") or env_cfg.get("ES_URL") or "").strip().rstrip("/")
    es_user = args.user or os.environ.get("ES_USER") or env_cfg.get("ES_USER") or ""
    es_pass = args.password or os.environ.get("ES_PASS") or env_cfg.get("ES_PASS") or ""
    so_url = (args.so_url or os.environ.get("SO_URL") or env_cfg.get("SO_URL") or "").strip().rstrip("/")

    script_dir = Path(__file__).resolve().parent
    raw_path = args.baseline_path or args.baseline_path_pos

    if not raw_path:
        roots = [p for p in (script_dir / "Output" / "Baselines", script_dir.parent / "Output" / "Baselines") if p.is_dir()]
        if not roots:
            sys.exit(f"ERROR: No --baseline-path specified and no 'Output/Baselines' directory found near '{script_dir}'.")
        baselines_root = roots[0]
        if args.all:
            baseline_path = baselines_root
        else:
            runs = sorted(baselines_root.glob("*Baselines_*"), key=lambda p: p.stat().st_mtime, reverse=True)
            if not runs:
                sys.exit(f"ERROR: No '*Baselines_*' folders found under '{baselines_root}'.")
            baseline_path = runs[0]
    else:
        baseline_path = Path(raw_path).expanduser().resolve()
        if not baseline_path.is_dir():
            sys.exit(f"ERROR: Baseline path not found: '{baseline_path}'")

    all_csvs = sorted(baseline_path.rglob("*.csv"))
    host_folders = sorted({f.parent for f in all_csvs})
    if not host_folders:
        sys.exit(f"ERROR: No baseline CSV files found under '{baseline_path}'.")

    headers = {"Accept": "application/json"}
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    if not args.dry_run:
        if not es_url:
            es_url = input("Enter Elasticsearch URL (e.g. https://10.0.0.10:9200): ").strip().rstrip("/")
        if not es_url:
            sys.exit("ERROR: Elasticsearch URL is required unless --dry-run or --self-test is used.")
        if es_user:
            token = base64.b64encode(f"{es_user}:{es_pass}".encode("utf-8")).decode("ascii")
            headers["Authorization"] = f"Basic {token}"

    mode_str = "DRY RUN (No HTTP calls)" if args.dry_run else ("Single Document POST (/_doc)" if args.single_doc else f"Bulk API (/_bulk, BatchSize={args.batch_size})")
    print("=================== Shipping Host Baseline ===================")
    print(f"Source Path    : {baseline_path}")
    print(f"Dataset Prefix : {args.dataset_prefix} (Module: {args.module_name})")
    print(f"Mode           : {mode_str}")

    shipped_suffixes = set()
    total_shipped = 0

    for host_dir in host_folders:
        host_name = host_dir.name
        csv_files = sorted(host_dir.glob("*.csv"))
        if not csv_files:
            continue
        parent_name = host_dir.parent.name if host_dir.parent else ""
        host_label = f"{parent_name}/{host_name}" if "Baselines_" in parent_name else host_name
        print(f"\n--- Host: {host_label} ({len(csv_files)} CSV file(s)) ---")

        for csv_file in csv_files:
            csv_base = csv_file.stem
            with csv_file.open("r", newline="", encoding="utf-8-sig", errors="replace") as f:
                rows = list(csv.DictReader(f))
            if not rows:
                continue

            docs = []
            suffix = None
            for row in rows:
                suf, doc = convert_row(csv_base, row, host_name, args.dataset_prefix, args.module_name, args.ingest_timestamp)
                if suf and doc:
                    suffix = suf
                    docs.append(doc)

            if not docs or not suffix:
                print(f"  [{csv_base}] Skipped (no shippable records).")
                continue

            index_name = f"logs-{args.dataset_prefix}.{suffix}-default"
            shipped_suffixes.add(suffix)

            if args.dry_run:
                print(f"  [{csv_base}] Parsed {len(docs)} doc(s) -> {index_name}")
                total_shipped += len(docs)
                continue

            if args.single_doc:
                doc_url = f"{es_url}/{index_name}/_doc"
                ok = 0
                for doc in docs:
                    try:
                        post_json(doc_url, json.dumps(doc).encode("utf-8"), "application/json; charset=utf-8", headers, ssl_ctx)
                        ok += 1
                    except Exception as e:
                        print(f"  WARNING: [{csv_base}] POST failed to {doc_url}: {e}", file=sys.stderr)
                print(f"  [{csv_base}] Shipped {ok} / {len(docs)} doc(s) -> {index_name}/_doc")
                total_shipped += ok
            else:
                bulk_url = f"{es_url}/{index_name}/_bulk"
                sent = 0
                for i in range(0, len(docs), args.batch_size):
                    batch = docs[i : i + args.batch_size]
                    ndjson = "".join(f'{{"create":{{}}}}\n{json.dumps(d)}\n' for d in batch).encode("utf-8")
                    try:
                        resp = post_json(bulk_url, ndjson, "application/x-ndjson; charset=utf-8", headers, ssl_ctx)
                        if resp.get("errors"):
                            failed = sum(1 for item in resp.get("items", []) if item.get("create", {}).get("error"))
                            sent += len(batch) - failed
                            print(f"  WARNING: [{csv_base}] Bulk batch had {failed} error(s).", file=sys.stderr)
                        else:
                            sent += len(batch)
                    except Exception as e:
                        print(f"  WARNING: [{csv_base}] Bulk POST failed to {bulk_url}: {e}", file=sys.stderr)
                print(f"  [{csv_base}] Shipped {sent} / {len(docs)} doc(s) -> {index_name}/_bulk")
                total_shipped += sent

    print("\n=================== Summary ===================")
    print(f"Total Documents {'Parsed' if args.dry_run else 'Shipped'}: {total_shipped}")

    if shipped_suffixes:
        if not so_url:
            parsed_host = urllib.parse.urlparse(es_url).hostname if es_url else None
            so_url = f"https://{parsed_host}" if parsed_host else "https://securityonion"

        link_lines = [
            f"# Security Onion Hunt Links ({datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%SZ')})",
            f"# Source: {baseline_path}",
            "",
        ]
        print("\n--- Security Onion Hunt Links ---")
        for suf, (fields, group_by) in HUNT_METADATA.items():
            if suf not in shipped_suffixes:
                continue
            dataset = f"{args.dataset_prefix}.{suf}"
            group_part = "".join(f"+|+groupby+%22{g_field}%22" for g_field in group_by)
            hunt_url = f"{so_url}/#/hunt?q=event.dataset:+%22{dataset}%22+|+table+soc_timestamp+{fields}{group_part}&z=America/New_York&el=100&gl=10&rt=24&rtu=hours"
            line = f"[{dataset}] {hunt_url}"
            print(line)
            link_lines.append(line)

        links_out = Path(args.links_file).expanduser().resolve() if args.links_file else (baseline_path / "hunt_links.txt")
        try:
            links_out.write_text("\n".join(link_lines) + "\n", encoding="utf-8")
            print(f"\n-> Saved Security Onion Hunt links to: {links_out}")
        except Exception as e:
            print(f"\nWARNING: Could not write Hunt links file '{links_out}': {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
