#!/usr/bin/env python3
"""Audit and snapshot Emburk's dynamically discovered GitHub Project."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import html
import json
import subprocess
import sys
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    from project_governance_audit import AuditError, ProjectRef, discover, run_gh
except ModuleNotFoundError:  # Imported as scripts.project_delivery in unit tests.
    from scripts.project_governance_audit import AuditError, ProjectRef, discover, run_gh


REQUIRED_FIELDS = {"Status", "Story Points", "Priority", "Owner Role", "Work Type", "Iteration", "Start date", "Target date"}
REQUIRED_VIEWS = {"Backlog", "Current iteration", "In progress", "Blocked", "By owner", "Roadmap", "Recently completed", "Needs iteration", "Needs estimate"}
REQUIRED_WORKFLOWS = {"Item added to project", "Item closed", "Pull request merged", "Pull request linked to issue"}
DONE = "Done"


@dataclass(frozen=True)
class Snapshot:
    date: str
    iteration: str
    start_date: str
    duration: int
    total_issues: int
    total_points: float
    remaining_issues: int
    remaining_points: float
    completed_issues: int
    completed_points: float
    status_counts: dict[str, int]


def project_query(project: ProjectRef) -> dict[str, Any]:
    query = """query($login:String!,$number:Int!){user(login:$login){projectV2(number:$number){fields(first:100){nodes{... on ProjectV2FieldCommon{name}}} views(first:50){nodes{name layout filter}} workflows(first:50){nodes{name enabled}}}}}"""
    response = run_gh("api", "graphql", "-f", f"query={query}", "-F", f"login={project.owner}", "-F", f"number={project.number}")
    return response["data"]["user"]["projectV2"]


def audit_configuration(project: ProjectRef | None = None) -> dict[str, Any]:
    project = project or discover()
    data = project_query(project)
    fields = {node["name"] for node in data["fields"]["nodes"]}
    views = {node["name"]: node for node in data["views"]["nodes"]}
    workflows = {node["name"] for node in data["workflows"]["nodes"] if node["enabled"]}
    missing = {
        "fields": sorted(REQUIRED_FIELDS - fields),
        "views": sorted(REQUIRED_VIEWS - set(views)),
        "workflows": sorted(REQUIRED_WORKFLOWS - workflows),
    }
    if any(missing.values()):
        raise AuditError("Project delivery configuration is incomplete: " + json.dumps(missing, sort_keys=True))
    return {
        "project": {"title": project.title, "url": project.url},
        "fields": sorted(REQUIRED_FIELDS),
        "views": {name: views[name] for name in sorted(REQUIRED_VIEWS)},
        "workflows": sorted(REQUIRED_WORKFLOWS),
        "result": "pass",
    }


def current_iteration(items: Iterable[dict[str, Any]], today: dt.date) -> dict[str, Any]:
    candidates: dict[str, dict[str, Any]] = {}
    for item in items:
        iteration = item.get("iteration")
        if not iteration:
            continue
        start = dt.date.fromisoformat(iteration["startDate"])
        end = start + dt.timedelta(days=int(iteration["duration"]))
        if start <= today < end:
            candidates[iteration["iterationId"]] = iteration
    if len(candidates) != 1:
        raise AuditError(f"expected exactly one populated current iteration; found {len(candidates)}")
    return next(iter(candidates.values()))


def make_snapshot(items: Iterable[dict[str, Any]], today: dt.date) -> Snapshot:
    items = list(items)
    iteration = current_iteration(items, today)
    selected = [item for item in items if item.get("iteration", {}).get("iterationId") == iteration["iterationId"] and item.get("content", {}).get("type") == "Issue"]
    statuses = Counter(item.get("status") or "Unspecified" for item in selected)
    remaining = [item for item in selected if item.get("status") != DONE]
    completed = [item for item in selected if item.get("status") == DONE]

    def points(item: dict[str, Any]) -> float:
        value = item.get("story Points")
        return float(value) if value is not None else 0.0

    return Snapshot(today.isoformat(), iteration["title"], iteration["startDate"], int(iteration["duration"]), len(selected), sum(map(points, selected)), len(remaining), sum(map(points, remaining)), len(completed), sum(map(points, completed)), dict(sorted(statuses.items())))


CSV_FIELDS = ("date", "iteration", "start_date", "duration", "total_issues", "total_points", "remaining_issues", "remaining_points", "completed_issues", "completed_points", "status_counts")


def csv_safe(value: str) -> str:
    return "'" + value if value.startswith(("=", "+", "-", "@")) else value


def append_snapshot(path: Path, snapshot: Snapshot) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    if path.exists():
        with path.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
    row = asdict(snapshot)
    row["status_counts"] = json.dumps(row["status_counts"], sort_keys=True)
    encoded = {key: csv_safe(str(row[key])) for key in CSV_FIELDS}
    rows = [existing for existing in rows if existing["date"] != snapshot.date]
    rows.append(encoded)
    rows.sort(key=lambda value: value["date"])
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    return rows


def ideal_remaining(initial: float, start_date: str, duration: int, date: str) -> float:
    start = dt.date.fromisoformat(start_date)
    current = dt.date.fromisoformat(date)
    elapsed = min(max((current - start).days, 0), duration)
    return max(0.0, initial * (1.0 - elapsed / duration))


def render_svg(rows: list[dict[str, str]], path: Path, metric: str, title: str) -> None:
    width, height, margin = 900, 420, 60
    total_key = "total_points" if metric == "remaining_points" else "total_issues"
    initial = float(rows[0][total_key])
    maximum = max(initial, *(float(row[metric]) for row in rows), 1.0)
    duration, start = int(rows[0]["duration"]), rows[0]["start_date"]

    def x(date: str) -> float:
        day = (dt.date.fromisoformat(date) - dt.date.fromisoformat(start)).days
        return margin + (width - 2 * margin) * min(max(day, 0), duration) / duration

    def y(value: float) -> float:
        return height - margin - (height - 2 * margin) * value / maximum

    actual = " ".join(f"{x(row['date']):.1f},{y(float(row[metric])):.1f}" for row in rows)
    end = (dt.date.fromisoformat(start) + dt.timedelta(days=duration)).isoformat()
    ideal = f"{x(start):.1f},{y(initial):.1f} {x(end):.1f},{y(0):.1f}"
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<rect width="100%" height="100%" fill="white"/><text x="{margin}" y="32" font-family="sans-serif" font-size="20">{html.escape(title)}</text>
<line x1="{margin}" y1="{height-margin}" x2="{width-margin}" y2="{height-margin}" stroke="#57606a"/><line x1="{margin}" y1="{margin}" x2="{margin}" y2="{height-margin}" stroke="#57606a"/>
<polyline points="{ideal}" fill="none" stroke="#8c959f" stroke-width="2" stroke-dasharray="8 6"/><polyline points="{actual}" fill="none" stroke="#0969da" stroke-width="3"/>
<text x="{width-250}" y="32" font-family="sans-serif" font-size="13" fill="#8c959f">--- ideal</text><text x="{width-150}" y="32" font-family="sans-serif" font-size="13" fill="#0969da">— actual</text></svg>'''
    path.write_text(svg, encoding="utf-8")


def snapshot(output_dir: Path, today: dt.date) -> dict[str, Any]:
    project = discover()
    result = run_gh("project", "item-list", str(project.number), "--owner", project.owner, "--limit", "500", "--format", "json")
    value = make_snapshot(result.get("items", []), today)
    stem = value.iteration.replace("/", "-")
    rows = append_snapshot(output_dir / f"{stem}.csv", value)
    (output_dir / f"{stem}-latest.json").write_text(json.dumps(asdict(value), indent=2, sort_keys=True) + "\n", encoding="utf-8")
    render_svg(rows, output_dir / f"{stem}-issues.svg", "remaining_issues", f"{stem} remaining issues")
    render_svg(rows, output_dir / f"{stem}-points.svg", "remaining_points", f"{stem} remaining Story Points")
    return {"project": project.url, "snapshot": asdict(value), "output": str(output_dir)}


def review_candidate(items: Iterable[dict[str, Any]], issue_urls: Iterable[str]) -> str:
    urls = list(issue_urls)
    if len(urls) != 1:
        raise AuditError(f"review automation requires exactly one closing Issue; found {len(urls)}")
    matches = [item for item in items if item.get("content", {}).get("url") == urls[0]]
    if len(matches) != 1:
        raise AuditError(f"review automation requires exactly one Project item; found {len(matches)}")
    candidate = matches[0]
    if candidate.get("content", {}).get("type") != "Issue":
        raise AuditError("review automation target is not an Issue")
    if candidate.get("status") != "In Progress":
        raise AuditError(f"review automation requires In Progress; found {candidate.get('status')!r}")
    if not candidate.get("id"):
        raise AuditError("review automation target has no Project item ID")
    return candidate["id"]


def project_id(project: ProjectRef) -> str:
    query = "query($login:String!,$number:Int!){user(login:$login){projectV2(number:$number){id}}}"
    response = run_gh("api", "graphql", "-f", f"query={query}", "-F", f"login={project.owner}", "-F", f"number={project.number}")
    return response["data"]["user"]["projectV2"]["id"]


def move_linked_issues_to_review(pr_number: int) -> dict[str, Any]:
    project = discover()
    repository = run_gh("repo", "view", "--json", "nameWithOwner")
    owner, name = repository["nameWithOwner"].split("/", 1)
    query = """query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){closingIssuesReferences(first:50){nodes{url}}}}}"""
    response = run_gh("api", "graphql", "-f", f"query={query}", "-F", f"owner={owner}", "-F", f"name={name}", "-F", f"number={pr_number}")
    urls = [node["url"] for node in response["data"]["repository"]["pullRequest"]["closingIssuesReferences"]["nodes"]]
    items = run_gh("project", "item-list", str(project.number), "--owner", project.owner, "--limit", "500", "--format", "json").get("items", [])
    item_id = review_candidate(items, urls)
    fields = run_gh("project", "field-list", str(project.number), "--owner", project.owner, "--limit", "100", "--format", "json")["fields"]
    status = next(field for field in fields if field["name"] == "Status")
    review = next(option for option in status["options"] if option["name"] == "Review")
    resolved_project_id = project_id(project)
    subprocess.run(["gh", "project", "item-edit", "--id", item_id, "--project-id", resolved_project_id, "--field-id", status["id"], "--single-select-option-id", review["id"]], check=True, capture_output=True, text=True)
    return {"project": project.url, "pull_request": pr_number, "linked_issues": 1, "updated_items": 1}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("audit")
    snapshot_parser = sub.add_parser("snapshot")
    snapshot_parser.add_argument("--output-dir", type=Path, required=True)
    snapshot_parser.add_argument("--date", type=dt.date.fromisoformat, default=dt.date.today())
    review_parser = sub.add_parser("review")
    review_parser.add_argument("--pr", type=int, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "audit":
            result = audit_configuration()
        elif args.command == "snapshot":
            result = snapshot(args.output_dir, args.date)
        else:
            result = move_linked_issues_to_review(args.pr)
        print(json.dumps(result, sort_keys=True))
    except (AuditError, KeyError, ValueError, json.JSONDecodeError, subprocess.CalledProcessError) as exc:
        print(f"project delivery failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
