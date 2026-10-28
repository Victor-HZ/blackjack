#!/usr/bin/env python3
"""Publish concise Xcode failure diagnostics without changing the build/test outcome.

Reads only known compiler/test error lines and xcresult testFailures. Full logs stay
in the workflow artifact; no environment variables or unrelated log lines are emitted.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys


ERROR = re.compile(r"(?:^|\s)(?:fatal )?error:\s+", re.IGNORECASE)
FAILED_CASE = re.compile(r"^\s*Test Case\s+.+\s+failed(?:\s|[.(])")
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
MAX_MESSAGES = 20
MAX_LENGTH = 1500


def concise(value: str, root: Path) -> str:
    text = ANSI.sub('', value).strip()
    text = text.replace(str(root.resolve()) + '/', '')
    return text[:MAX_LENGTH] + (' …' if len(text) > MAX_LENGTH else '')


def messages(directory: Path, root: Path) -> list[str]:
    found: list[str] = []
    for name in ['release-build.log', 'ui-tests.log']:
        path = directory / name
        if not path.is_file():
            continue
        with path.open(errors='replace') as stream:
            for line in stream:
                clean = ANSI.sub('', line)
                if ERROR.search(clean) or FAILED_CASE.search(clean):
                    found.append(concise(clean, root))
    summary = directory / 'test-summary.json'
    if summary.is_file():
        try:
            data = json.loads(summary.read_text())
            failures = data.get('testFailures', []) if isinstance(data, dict) else []
            for failure in failures if isinstance(failures, list) else []:
                if not isinstance(failure, dict):
                    continue
                description = failure.get('failureText') or failure.get('message')
                if not isinstance(description, str) or not description.strip():
                    continue
                name = failure.get('testName') or failure.get('testIdentifier')
                prefix = name + ': ' if isinstance(name, str) else ''
                found.append(concise(prefix + description, root))
        except (OSError, ValueError):
            # An unavailable xcresult command must not hide plain-text diagnostics.
            pass
    return list(dict.fromkeys(found))[:MAX_MESSAGES]


def escape_command(text: str) -> str:
    # GitHub's workflow-command protocol uses literal percent/newline escapes.
    return text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path, nargs='?', default=Path('TestResults'))
    parser.add_argument('--repository-root', type=Path, default=Path.cwd())
    args = parser.parse_args()
    diagnostics = messages(args.directory, args.repository_root)
    for message in diagnostics:
        print('::error title=Xcode diagnostic::' + escape_command(message))
    if not diagnostics:
        print('No compiler or test failure diagnostics were found in the available Xcode output.')
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        with Path(summary_path).open('a') as summary:
            summary.write('### Xcode diagnostics\n\n')
            if diagnostics:
                summary.write('Build/test failures reported by Xcode (up to 20):\n\n')
                # Indented code keeps failure text literal, including Markdown fences.
                for message in diagnostics:
                    summary.write('\n'.join('    ' + line for line in message.splitlines()) + '\n\n')
            else:
                summary.write('No compiler or test failure diagnostics were found. Check the original step status; this does not establish that tests ran.\n\n')
            summary.write('Full logs and any test result bundle are in the **ios-test-results** artifact.\n')
    # This reporting step never determines success: xcodebuild retains its exit status.
    return 0


if __name__ == '__main__':
    sys.exit(main())
