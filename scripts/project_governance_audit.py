#!/usr/bin/env python3
"""Fail-closed, read-only audit for Emburk's GitHub Project governance."""

from __future__ import annotations

import json
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, Iterable


REQUIRED_SECTIONS = (
    "Authority",
    "Dependencies",
    "Branch and allowlist",
    "Artifacts",
    "Acceptance criteria",
    "Demo Command",
    "Evidence class",
    "Stop rule",
    "Non-claims",
)
ACTIVE_STATUSES = frozenset({"In Progress", "Review"})
WIP_LIMIT = 2


class AuditError(RuntimeError):
    """Raised when governance cannot be established unambiguously."""


@dataclass(frozen=True)
class ProjectRef:
    owner: str
    number: int
    title: str
    url: str


def validate_packet(body: str) -> list[str]:
    """Return required Markdown section names missing from an Issue body."""
    headings = {
        line[3:].strip().casefold()
        for line in body.splitlines()
        if line.startswith("## ")
    }
    return [section for section in REQUIRED_SECTIONS if section.casefold() not in headings]


def count_wip(items: Iterable[dict[str, Any]]) -> int:
    """Count items occupying the combined execution and review lanes."""
    return sum(1 for item in items if item.get("status") in ACTIVE_STATUSES)


def enforce_wip(items: Iterable[dict[str, Any]], limit: int = WIP_LIMIT) -> int:
    count = count_wip(items)
    if count > limit:
        raise AuditError(f"combined In Progress/Review WIP is {count}; limit is {limit}")
    return count


def select_project(nodes: Iterable[dict[str, Any]]) -> ProjectRef:
    open_projects = [node for node in nodes if not node.get("closed", False)]
    if len(open_projects) != 1:
        raise AuditError(
            "expected exactly one open Project linked to the repository; "
            f"found {len(open_projects)}"
        )
    node = open_projects[0]
    owner = node.get("owner", {}).get("login")
    number = node.get("number")
    title = node.get("title")
    url = node.get("url")
    if not owner or not isinstance(number, int) or not title or not url:
        raise AuditError("linked Project metadata is incomplete")
    return ProjectRef(owner=owner, number=number, title=title, url=url)


def run_gh(*args: str, stdin: str | None = None) -> Any:
    command = ["gh", *args]
    completed = subprocess.run(
        command,
        input=stdin,
        text=True,
        check=True,
        capture_output=True,
    )
    return json.loads(completed.stdout)


def discover() -> ProjectRef:
    repository = run_gh("repo", "view", "--json", "nameWithOwner")
    owner, name = repository["nameWithOwner"].split("/", 1)
    query = """query($owner:String!,$name:String!){
      repository(owner:$owner,name:$name){
        projectsV2(first:20){nodes{id number title url closed owner{... on User{login} ... on Organization{login}}}}
      }
    }"""
    response = run_gh(
        "api",
        "graphql",
        "-f",
        f"query={query}",
        "-F",
        f"owner={owner}",
        "-F",
        f"name={name}",
    )
    nodes = response["data"]["repository"]["projectsV2"]["nodes"]
    return select_project(nodes)


def audit() -> dict[str, Any]:
    project = discover()
    result = run_gh(
        "project",
        "item-list",
        str(project.number),
        "--owner",
        project.owner,
        "--limit",
        "500",
        "--format",
        "json",
    )
    items = result.get("items", [])
    wip = enforce_wip(items)
    return {
        "project": {"title": project.title, "url": project.url},
        "items": len(items),
        "combined_wip": wip,
        "wip_limit": WIP_LIMIT,
        "result": "pass",
    }


def main(argv: list[str]) -> int:
    if argv != ["audit"]:
        print("usage: project_governance_audit.py audit", file=sys.stderr)
        return 2
    try:
        print(json.dumps(audit(), sort_keys=True))
    except (AuditError, KeyError, json.JSONDecodeError, subprocess.CalledProcessError) as exc:
        print(f"governance audit failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
