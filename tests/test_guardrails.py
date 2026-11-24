import os
import pathlib
import re
import subprocess
from typing import Any, Dict, List, Tuple

import pytest
import yaml

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent

TERRAFORM_DIRS = [
    REPO_ROOT / "modules" / "nrql-deadman-watchdog",
    REPO_ROOT / "modules" / "nrql-distinct-session-alert",
    REPO_ROOT / "modules" / "cw-metric-stream-filter",
    REPO_ROOT / "examples" / "synthetic-platform-stack",
]

REQUIRED_TF_FILES = ("versions.tf", "variables.tf", "main.tf", "outputs.tf")

AI_SLOP_PHRASES = (
    "production-grade",
    "robust",
    "comprehensive",
    "battle-tested",
    "seamlessly",
)

DANGEROUS_K8S_KINDS = {"ClusterRole", "ClusterRoleBinding"}


def _read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def _iter_repo_text_files() -> List[pathlib.Path]:
    skip_dirs = {".git", ".terraform", ".pytest_cache", "__pycache__", ".venv", "venv"}
    files: List[pathlib.Path] = []
    for path in REPO_ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in skip_dirs for part in path.parts):
            continue
        files.append(path)
    return sorted(files)


def _strip_hcl_comments_and_strings(source: str) -> str:
    """Strip HCL comments and quoted strings so delimiter checks inspect structure only."""
    out: List[str] = []
    i = 0
    n = len(source)
    in_string = False
    in_line_comment = False
    in_block_comment = False

    while i < n:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < n else ""

        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
                out.append(ch)
            i += 1
            continue

        if in_block_comment:
            if ch == "*" and nxt == "/":
                in_block_comment = False
                i += 2
            else:
                i += 1
            continue

        if in_string:
            if ch == "\\" and nxt:
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue

        if ch == "#":
            in_line_comment = True
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue

        if ch == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue

        if ch == '"':
            in_string = True
            i += 1
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def _check_balanced_delimiters(text: str) -> str:
    stripped = _strip_hcl_comments_and_strings(text)
    pairs = {"{": "}", "[": "]", "(": ")"}
    closing = {v: k for k, v in pairs.items()}
    stack: List[Tuple[str, int]] = []
    line = 1

    for ch in stripped:
        if ch == "\n":
            line += 1
        elif ch in pairs:
            stack.append((ch, line))
        elif ch in closing:
            if not stack or stack[-1][0] != closing[ch]:
                return f"Unmatched closing '{ch}' on line {line}"
            stack.pop()

    if stack:
        open_ch, open_line = stack[-1]
        return f"Unclosed '{open_ch}' opened on line {open_line}"
    return ""


def test_required_repository_layout_exists() -> None:
    required_paths = [
        REPO_ROOT / "README.md",
        REPO_ROOT / "LICENSE",
        REPO_ROOT / ".gitignore",
        REPO_ROOT / ".github" / "workflows" / "ci.yml",
        REPO_ROOT / "examples" / "synthetic-platform-stack" / "terraform.tfvars.example",
        REPO_ROOT / "k8s" / "spot-ha-overlay" / "base" / "deployment.yaml",
        REPO_ROOT / "k8s" / "spot-ha-overlay" / "base" / "pdb.yaml",
        REPO_ROOT / "k8s" / "spot-ha-overlay" / "base" / "kustomization.yaml",
        REPO_ROOT / "k8s" / "spot-ha-overlay" / "overlays" / "prod-spot-ha" / "patch-topology-spread.yaml",
        REPO_ROOT / "k8s" / "spot-ha-overlay" / "overlays" / "prod-spot-ha" / "kustomization.yaml",
        REPO_ROOT / "k8s" / "spot-ha-overlay" / "argocd" / "application.yaml",
    ]
    for path in required_paths:
        assert path.is_file(), f"Missing required file: {path}"


@pytest.mark.parametrize("tf_dir", TERRAFORM_DIRS, ids=lambda p: p.name)
def test_terraform_directory_structure_and_syntax(tf_dir: pathlib.Path) -> None:
    for filename in REQUIRED_TF_FILES:
        file_path = tf_dir / filename
        assert file_path.is_file(), f"Missing {filename} in {tf_dir}"
        content = _read_text(file_path)
        assert content.strip(), f"Empty Terraform file: {file_path}"
        assert content.endswith("\n"), f"Missing trailing newline in {file_path}"
        assert "\t" not in content, f"Tabs are disallowed in Terraform fmt: {file_path}"
        err = _check_balanced_delimiters(content)
        assert err == "", f"{file_path}: {err}"

    variables_text = _read_text(tf_dir / "variables.tf")
    assert "validation {" in variables_text, f"Expected variable validation blocks in {tf_dir / 'variables.tf'}"


def test_deadman_watchdog_guardrails() -> None:
    tf_dir = REPO_ROOT / "modules" / "nrql-deadman-watchdog"
    versions_text = _read_text(tf_dir / "versions.tf")
    main_text = _read_text(tf_dir / "main.tf")
    vars_text = _read_text(tf_dir / "variables.tf")

    assert ">= 1.6.0" in versions_text
    assert "newrelic/newrelic" in versions_text
    assert "~> 3.30" in versions_text

    assert 'resource "newrelic_nrql_alert_condition" "deadman"' in main_text
    assert re.search(r'\btype\s+=\s+"static"', main_text)
    assert re.search(r'\bfill_option\s+=\s+"static"', main_text)
    assert re.search(r"\bfill_value\s+=\s+0\b", main_text)
    assert re.search(r"\bexpiration_duration\s+=\s+var\.expiration_duration_seconds\b", main_text)
    assert re.search(r"\bopen_violation_on_expiration\s+=\s+true\b", main_text)
    assert re.search(r"\bclose_violations_on_expiration\s+=\s+true\b", main_text)
    assert re.search(r'\boperator\s+=\s+"equals"', main_text)
    assert re.search(r"\bthreshold\s+=\s+0\b", main_text)
    assert re.search(r'\bthreshold_occurrences\s+=\s+"all"', main_text)
    assert "nrql {" in main_text
    assert "expiration {" not in main_text, "Deadman expiration uses top-level attributes in New Relic v3 provider"
    assert "precondition {" in main_text
    assert "1200" in main_text
    assert "% var.slide_by_seconds == 0" in main_text

    assert re.search(r'\bdefault\s+=\s+"event_flow"', vars_text)
    assert "nullable    = false" in vars_text
    assert "aggregation_delay_seconds" in vars_text
    assert "aggregation_timer_seconds" in vars_text


def test_distinct_session_alert_guardrails() -> None:
    tf_dir = REPO_ROOT / "modules" / "nrql-distinct-session-alert"
    main_text = _read_text(tf_dir / "main.tf")
    vars_text = _read_text(tf_dir / "variables.tf")

    assert 'resource "newrelic_nrql_alert_condition" "distinct_session"' in main_text
    assert "nrql {" in main_text
    assert "critical {" in main_text
    assert 'dynamic "warning"' in main_text
    assert "coalesce(var.warning_operator, var.critical_operator)" in main_text
    assert "precondition {" in main_text
    assert 'var.fill_option != "static" || var.fill_value != null' in main_text
    assert "warning_operator" in vars_text
    assert "nullable    = false" in vars_text
    assert "uniqueCount" in vars_text
    assert "filter" in vars_text
    assert 'contains(["static", "baseline"]' in vars_text


def test_cw_metric_stream_filter_guardrails() -> None:
    tf_dir = REPO_ROOT / "modules" / "cw-metric-stream-filter"
    versions_text = _read_text(tf_dir / "versions.tf")
    main_text = _read_text(tf_dir / "main.tf")
    vars_text = _read_text(tf_dir / "variables.tf")

    assert "hashicorp/aws" in versions_text
    assert "~> 5.0" in versions_text

    assert 'resource "aws_cloudwatch_metric_stream" "this"' in main_text
    assert 'dynamic "include_filter"' in main_text
    assert not re.search(
        r'(?:^|\s)(?:dynamic\s+"exclude_filter"|exclude_filter\s*\{)',
        main_text,
    ), "include_filter and exclude_filter are mutually exclusive"

    for fmt in ("opentelemetry0.7", "opentelemetry1.0", "json"):
        assert fmt in vars_text
    assert "length(var.include_filters) > 0" in vars_text
    assert "length(f.metric_names) > 0" in vars_text
    assert "length(trimspace(m)) > 0" in vars_text
    assert "nullable    = false" in vars_text


def test_synthetic_example_wires_all_modules() -> None:
    example_main = _read_text(REPO_ROOT / "examples" / "synthetic-platform-stack" / "main.tf")
    assert 'source = "../../modules/nrql-deadman-watchdog"' in example_main
    assert 'source = "../../modules/nrql-distinct-session-alert"' in example_main
    assert 'source = "../../modules/cw-metric-stream-filter"' in example_main
    assert "checkout-api" in example_main
    assert "nightly-etl-worker" in example_main
    assert "session-cache" in example_main
    assert "AWS/ElastiCache" in example_main
    assert "AWS/RDS" in example_main


def test_kubernetes_and_argocd_manifests() -> None:
    k8s_root = REPO_ROOT / "k8s" / "spot-ha-overlay"
    yaml_files = sorted(k8s_root.rglob("*.yaml"))
    assert len(yaml_files) == 6

    docs: Dict[pathlib.Path, Dict[str, Any]] = {}
    for yf in yaml_files:
        parsed = yaml.safe_load(_read_text(yf))
        assert isinstance(parsed, dict), f"YAML did not parse to mapping: {yf}"
        assert "apiVersion" in parsed, f"Missing apiVersion in {yf}"
        assert "kind" in parsed, f"Missing kind in {yf}"
        assert parsed["kind"] not in DANGEROUS_K8S_KINDS, f"Disallowed kind {parsed['kind']} in {yf}"
        docs[yf] = parsed

    base_dep = docs[k8s_root / "base" / "deployment.yaml"]
    pod_spec = base_dep["spec"]["template"]["spec"]
    assert pod_spec.get("automountServiceAccountToken") is False
    assert pod_spec["securityContext"]["runAsNonRoot"] is True
    container = pod_spec["containers"][0]
    assert "example-org/" in container["image"]
    c_sec = container["securityContext"]
    assert c_sec["runAsNonRoot"] is True
    assert c_sec["allowPrivilegeEscalation"] is False
    assert c_sec["readOnlyRootFilesystem"] is True
    assert c_sec.get("privileged") is not True
    assert "ALL" in c_sec["capabilities"]["drop"]
    assert "requests" in container["resources"] and "limits" in container["resources"]
    assert "readinessProbe" in container and "livenessProbe" in container

    base_pdb = docs[k8s_root / "base" / "pdb.yaml"]
    assert base_pdb["kind"] == "PodDisruptionBudget"
    assert int(base_pdb["spec"]["minAvailable"]) >= 1

    overlay_patch = docs[k8s_root / "overlays" / "prod-spot-ha" / "patch-topology-spread.yaml"]
    assert int(overlay_patch["spec"]["replicas"]) >= 2
    constraints = overlay_patch["spec"]["template"]["spec"]["topologySpreadConstraints"]
    by_key = {c["topologyKey"]: c for c in constraints}
    assert "kubernetes.io/hostname" in by_key
    assert by_key["kubernetes.io/hostname"]["whenUnsatisfiable"] == "DoNotSchedule"
    assert int(by_key["kubernetes.io/hostname"]["maxSkew"]) == 1
    assert "topology.kubernetes.io/zone" in by_key
    assert by_key["topology.kubernetes.io/zone"]["whenUnsatisfiable"] == "ScheduleAnyway"

    argo_app = docs[k8s_root / "argocd" / "application.yaml"]
    assert argo_app["kind"] == "Application"
    assert "example-org/" in argo_app["spec"]["source"]["repoURL"]
    assert argo_app["spec"]["source"]["path"] == "k8s/spot-ha-overlay/overlays/prod-spot-ha"
    automated = argo_app["spec"]["syncPolicy"]["automated"]
    assert automated["prune"] is True
    assert automated["selfHeal"] is True


def test_readme_required_sections() -> None:
    readme = _read_text(REPO_ROOT / "README.md")
    for heading in (
        "Why This Exists",
        "Origin & Sanitization",
        "What It Intentionally Does Not Do",
        "Quickstart",
    ):
        assert heading in readme, f"Missing README section: {heading}"
    assert "```bash" in readme
    assert "kubectl kustomize" in readme


def test_ci_workflow_valid() -> None:
    ci_path = REPO_ROOT / ".github" / "workflows" / "ci.yml"
    ci = yaml.safe_load(_read_text(ci_path))
    assert "jobs" in ci
    assert "terraform-validate" in ci["jobs"]
    assert "python-guardrail-tests" in ci["jobs"]
    raw_ci = _read_text(ci_path)
    assert "NEW_RELIC_API_KEY" in raw_ci
    assert "NEW_RELIC_ACCOUNT_ID" in raw_ci
    assert "terraform fmt -check -recursive" in raw_ci
    assert re.search(r"terraform\b.*\binit\s+-backend=false", raw_ci)
    assert re.search(r"terraform\b.*\bvalidate\b", raw_ci)
    assert "kubectl" in raw_ci and "kustomize" in raw_ci
    assert "pytest -v" in raw_ci


def test_sanitization_secrets_and_style_hygiene() -> None:
    # Optional untracked blocklist file supplied externally during pre-release checks.
    blocklist_terms: List[str] = []
    blocklist_env = os.environ.get("NDA_BLOCKLIST_PATH")
    if blocklist_env and pathlib.Path(blocklist_env).is_file():
        blocklist_terms = [
            line.strip().lower()
            for line in pathlib.Path(blocklist_env).read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.strip().startswith("#")
        ]

    non_zero_arn_re = re.compile(
        r"arn:aws[^:]*:[a-z0-9-]+:[a-z0-9-]*:(?!000000000000)[0-9]{12}:"
    )
    aws_key_re = re.compile(r"AKIA[0-9A-Z]{16}")

    texts_to_scan: List[Tuple[str, str]] = []
    for path in _iter_repo_text_files():
        rel = str(path.relative_to(REPO_ROOT))
        texts_to_scan.append((rel, _read_text(path)))

    if (REPO_ROOT / ".git").exists():
        log_proc = subprocess.run(
            ["git", "-C", str(REPO_ROOT), "log", "--all", "--format=%s%n%b"],
            capture_output=True,
            text=True,
            check=False,
        )
        if log_proc.returncode == 0 and log_proc.stdout:
            texts_to_scan.append(("git-commit-history", log_proc.stdout))

    nr_key_prefix = "NRAK" + "-"
    slack_webhook_prefix = "hooks.slack.com" + "/services/"

    for source_name, content in texts_to_scan:
        lowered = content.lower()
        for term in blocklist_terms:
            assert term not in lowered, f"Blocked identifier detected in {source_name}"

        assert not non_zero_arn_re.search(content), f"Non-synthetic AWS account ARN in {source_name}"
        assert not aws_key_re.search(content), f"AWS access key pattern in {source_name}"
        assert nr_key_prefix not in content, f"New Relic API key pattern in {source_name}"
        assert slack_webhook_prefix not in content, f"Slack webhook URL in {source_name}"
        assert "\u2014" not in content, f"Em-dash found in {source_name}"

        if source_name not in {"tests\\test_guardrails.py", "tests/test_guardrails.py"}:
            for phrase in AI_SLOP_PHRASES:
                assert phrase not in lowered, f"Disallowed style phrase '{phrase}' in {source_name}"
