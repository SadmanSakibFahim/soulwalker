from __future__ import annotations

import argparse
import asyncio
import sys
from collections.abc import Sequence

from soulwalker.config import get_settings
from soulwalker.db.session import SessionLocal
from soulwalker.services.content_lint import lint_content
from soulwalker.services.content_seed import seed_content


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="soulwalker")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("lint-content", help="Validate YAML world packs")
    sub.add_parser("seed", help="Upsert world packs into Postgres")
    args = parser.parse_args(argv)

    settings = get_settings()
    if args.command == "lint-content":
        issues = lint_content(settings.content_root)
        if not issues:
            print("content ok")
            return 0
        for issue in issues:
            print(f"{issue.path}: {issue.message}", file=sys.stderr)
        return 1
    if args.command == "seed":
        return asyncio.run(_seed(settings.content_root))
    return 1


async def _seed(content_root: object) -> int:
    from pathlib import Path

    async with SessionLocal() as session:
        keys = await seed_content(session, Path(str(content_root)))
    print("seeded: " + ", ".join(keys))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
