# Host Baseline Elastic Stack Shipper (`Elastic-Shipper`)

Standalone Linux/Python (`ship_host_baseline.py`) and Windows/PowerShell (`Ship-HostBaseline.ps1`) parsers that read the 12 CSV datasets produced by `Get-HostBaseline` (`../Output/Baselines/HostBaselines_<timestamp>/<host>/*.csv`), transform them into the Elastic Stack / Security Onion schema, ship them via the Elasticsearch `_bulk` API (or `/_doc`), and write clickable Security Onion Hunt links to `hunt_links.txt`.

Both scripts use **zero external dependencies** (Python 3 standard library / built-in PowerShell) and share the same `.env` file.

---

## 1. Setup (`.env`)

1. Copy `.env.example` to `.env` inside `Elastic-Shipper/`:
   ```bash
   # Linux / macOS
   cp .env.example .env
   ```
   ```powershell
   # Windows PowerShell
   Copy-Item .env.example .env
   ```
2. Edit `.env` with your Elastic Stack / Security Onion details:
   ```ini
   ES_URL=https://10.0.0.10:9200
   ES_USER=elastic
   ES_PASS=changeme
   SO_URL=https://10.0.0.10
   ```

---

## 2. Linux / Python Usage (`ship_host_baseline.py`)

```bash
# Auto-detect and ship the newest baseline run under ../Output/Baselines
python3 ship_host_baseline.py

# Ship ALL baseline runs and hosts inside ../Output/Baselines (or a shared drive mount)
python3 ship_host_baseline.py --all
python3 ship_host_baseline.py /mnt/share/Baselines --all

# Ship a specific baseline run or single host folder
python3 ship_host_baseline.py ../Output/Baselines/HostBaselines_20261026_120000
python3 ship_host_baseline.py ../Output/Baselines/HostBaselines_20261026_120000/DC01

# Save Security Onion Hunt links to a specific shared file (defaults to <BaselinePath>/hunt_links.txt)
python3 ship_host_baseline.py --all --links-file /mnt/share/Baselines/hunt_links.txt

# Dry-run (parse CSVs and generate hunt_links.txt without sending HTTP requests)
python3 ship_host_baseline.py --all --dry-run

# Run built-in parser self-test
python3 ship_host_baseline.py --self-test
```

---

## 3. Windows / PowerShell Usage (`Ship-HostBaseline.ps1`)

```powershell
# Auto-detect and ship the newest baseline run under ..\Output\Baselines
.\Ship-HostBaseline.ps1

# Ship ALL baseline runs and hosts inside ..\Output\Baselines
.\Ship-HostBaseline.ps1 -All

# Ship a specific baseline run or single host folder (or shared drive path)
.\Ship-HostBaseline.ps1 -BaselinePath "\\fileserver\share\Baselines\HostBaselines_20261026_120000"

# Save Security Onion Hunt links to a custom .txt path (defaults to <BaselinePath>\hunt_links.txt)
.\Ship-HostBaseline.ps1 -All -LinksFile "\\fileserver\share\Baselines\hunt_links.txt"

# Pass credentials explicitly via CLI or PSCredential (overrides .env)
.\Ship-HostBaseline.ps1 -ElasticUrl "https://10.0.0.10:9200" -User "elastic" -Password "changeme"
.\Ship-HostBaseline.ps1 -ElasticUrl "https://10.0.0.10:9200" -Credential $esCred

# Dry-run (parse CSVs and generate hunt_links.txt without sending HTTP requests)
.\Ship-HostBaseline.ps1 -All -DryRun

# Run built-in parser self-test
.\Ship-HostBaseline.ps1 -SelfTest
```

---

## 4. Exported Hunt Links (`hunt_links.txt`)

Whenever documents are parsed or shipped, both scripts automatically write the clickable Security Onion Hunt links to:
- **Default**: `<BaselinePath>/hunt_links.txt` (right inside the baseline folder on your local or shared drive)
- **Custom**: Pass `--links-file /path/to/hunt_links.txt` (Python) or `-LinksFile .\path\to\hunt_links.txt` (PowerShell)

---

## 5. Options Reference

| Python Flag | PowerShell Parameter | Default | Description |
| :--- | :--- | :--- | :--- |
| `path` / `-p`, `--baseline-path` | `-BaselinePath` | Latest `*Baselines_*` | Path to `Output/Baselines`, a `HostBaselines_<timestamp>` folder, or a `<host>` folder |
| `-a`, `--all` | `-All` | `false` | Recursively ship every baseline run and host folder inside `../Output/Baselines` |
| `-u`, `--elastic-url` | `-ElasticUrl` | `ES_URL` in `.env` | Elasticsearch endpoint (e.g., `https://10.0.0.10:9200`) |
| `--user` / `--password` | `-User` / `-Password` | `ES_USER` / `ES_PASS` | Basic authentication username and password |
| *(N/A)* | `-Credential` | `$null` | Optional `[PSCredential]` object for Basic authentication |
| `--so-url` | `-SecurityOnionUrl` | `SO_URL` / `ES_URL` host | Base URL used when generating Security Onion Hunt links |
| `-l`, `--links-file` | `-LinksFile` | `<BaselinePath>/hunt_links.txt` | Output file path for saving clickable Security Onion Hunt URLs |
| `--env-file` | `-EnvFile` | `./.env` | Custom path to an environment configuration file |
| `--dataset-prefix` | `-DatasetPrefix` | `admintool.windows` | Prefix for data stream index (`logs-<prefix>.<type>-default`) and `event.dataset` |
| `--module-name` | `-ModuleName` | `admintool` | Value for `event.module` |
| `--batch-size` | `-BatchSize` | `500` | Number of documents per `_bulk` NDJSON request |
| `--single-doc` | `-UseSingleDoc` | `false` | Send one POST per row to `/_doc` instead of batching via `/_bulk` |
| `--ingest-timestamp` | `-UseIngestTimestamp` | `false` | Use current UTC time for `@timestamp` instead of the CSV capture timestamp |
| `--dry-run` | `-DryRun` | `false` | Parse CSVs and write `hunt_links.txt` without making HTTP requests |
| `--self-test` | `-SelfTest` | `false` | Run built-in validation of all 12 dataset parsers and CSV round-trips |

---

## 6. Dataset Mapping (`Get-HostBaseline` -> Elastic Stack)

| CSV File (`Get-HostBaseline`) | Data Stream Index | `event.dataset` | Root Object |
| :--- | :--- | :--- | :--- |
| `OSInfo.csv` | `logs-admintool.windows.osinfo-default` | `admintool.windows.osinfo` | `os_release` |
| `Processes.csv` | `logs-admintool.windows.processes-default` | `admintool.windows.processes` | `process` |
| `Services.csv` | `logs-admintool.windows.services-default` | `admintool.windows.services` | `service` |
| `Connections.csv` | `logs-admintool.windows.network-default` | `admintool.windows.network` | `connection` |
| `Shares.csv` | `logs-admintool.windows.shares-default` | `admintool.windows.shares` | `share` |
| `RegistryRun.csv` | `logs-admintool.windows.registryrunkeys-default` | `admintool.windows.registryrunkeys` | `registry` |
| `StartupFolders.csv` | `logs-admintool.windows.startup-default` | `admintool.windows.startup` | `startup_file` |
| `ScheduledTasks.csv` | `logs-admintool.windows.tasks-default` | `admintool.windows.tasks` | `task` |
| `LogonHistory.csv` | `logs-admintool.windows.logon-default` | `admintool.windows.logon` | `logon` |
| `LocalGroupMembers.csv` | `logs-admintool.windows.groupmembers-default` | `admintool.windows.groupmembers` | `group` |
| `RegistryUserShellFolders.csv` | `logs-admintool.windows.registryshellfolders-default` | `admintool.windows.registryshellfolders` | `shell_folder` |
| `Prefetches.csv` | `logs-admintool.windows.prefetch-default` | `admintool.windows.prefetch` | `prefetch` |
