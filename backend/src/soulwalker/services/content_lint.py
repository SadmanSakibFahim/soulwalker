from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

from soulwalker.domain.terminology import REQUIRED_TERM_KEYS
from soulwalker.enums import TriggerType

MIN_POOL_BY_TRIGGER: dict[TriggerType, int] = {
    TriggerType.DAILY_AMBIENT: 14,
    TriggerType.MILESTONE_KM: 5,
    TriggerType.ARMAMENT_UNLOCK: 5,
    TriggerType.BOSS_KILL: 5,
    TriggerType.BOSS_DEATH: 5,
    TriggerType.AFFLICTION_STATUS: 5,
    TriggerType.CHECKPOINT_RETURN: 5,
}


@dataclass(frozen=True, slots=True)
class LintIssue:
    path: str
    message: str


@dataclass(frozen=True, slots=True)
class WorldContent:
    directory: Path
    world_key: str
    name: str
    tone: str
    art_theme: str
    active: bool
    pillars: list[dict[str, object]]
    terms: dict[str, str]
    fragments: list[dict[str, object]]


def load_world_content(world_dir: Path) -> WorldContent:
    world_path = world_dir / "world.yaml"
    terms_path = world_dir / "terminology.yaml"
    world_data = _read_yaml(world_path)
    terms_data = _read_yaml(terms_path)
    if not isinstance(world_data, dict) or not isinstance(terms_data, dict):
        raise ValueError(f"world.yaml and terminology.yaml must be mappings in {world_dir}")

    fragments: list[dict[str, object]] = []
    fragments_dir = world_dir / "fragments"
    if fragments_dir.is_dir():
        for fragment_file in sorted(fragments_dir.glob("*.yaml")):
            payload = _read_yaml(fragment_file)
            if not isinstance(payload, list):
                raise ValueError(f"{fragment_file} must be a list of fragments")
            trigger_from_name = fragment_file.stem
            for item in payload:
                if not isinstance(item, dict):
                    raise ValueError(f"{fragment_file} contains a non-mapping fragment")
                item.setdefault("trigger_type", trigger_from_name)
                item["_source"] = str(fragment_file)
                fragments.append(item)

    pillars = world_data.get("pillars", [])
    if not isinstance(pillars, list):
        raise ValueError(f"{world_path} pillars must be a list")

    return WorldContent(
        directory=world_dir,
        world_key=str(world_data["world_key"]),
        name=str(world_data["name"]),
        tone=str(world_data["tone"]),
        art_theme=str(world_data["art_theme"]),
        active=bool(world_data.get("active", True)),
        pillars=pillars,
        terms={str(key): str(value) for key, value in terms_data.items()},
        fragments=fragments,
    )


def load_all_worlds(content_root: Path) -> list[WorldContent]:
    worlds_root = content_root / "worlds"
    if not worlds_root.is_dir():
        raise FileNotFoundError(f"missing content directory: {worlds_root}")
    worlds: list[WorldContent] = []
    for child in sorted(worlds_root.iterdir()):
        if child.is_dir() and (child / "world.yaml").exists():
            worlds.append(load_world_content(child))
    return worlds


def lint_content(content_root: Path) -> list[LintIssue]:
    issues: list[LintIssue] = []
    worlds = load_all_worlds(content_root)
    pillar_keys_by_world: dict[str, set[str]] = {}

    for world in worlds:
        issues.extend(_lint_world(world))
        pillar_keys_by_world[world.world_key] = _pillar_keys(world.pillars)

    issues.extend(_lint_cross_world_pillars(worlds, pillar_keys_by_world))
    return issues


def _lint_world(world: WorldContent) -> list[LintIssue]:
    issues: list[LintIssue] = []
    missing = sorted(REQUIRED_TERM_KEYS - set(world.terms))
    empty = sorted(key for key in REQUIRED_TERM_KEYS if not world.terms.get(key, "").strip())
    for key in missing:
        issues.append(LintIssue(str(world.directory / "terminology.yaml"), f"missing term {key}"))
    for key in empty:
        if key not in missing:
            issues.append(LintIssue(str(world.directory / "terminology.yaml"), f"empty term {key}"))

    pillar_keys = _pillar_keys(world.pillars)
    counts: dict[TriggerType, int] = dict.fromkeys(TriggerType, 0)
    seen_fragment_keys: set[str] = set()

    for fragment in world.fragments:
        source = str(fragment.get("_source", world.directory))
        fragment_key = str(fragment.get("fragment_key", ""))
        if not fragment_key:
            issues.append(LintIssue(source, "fragment missing fragment_key"))
            continue
        if fragment_key in seen_fragment_keys:
            issues.append(LintIssue(source, f"duplicate fragment_key {fragment_key}"))
        seen_fragment_keys.add(fragment_key)

        try:
            trigger = TriggerType(str(fragment["trigger_type"]))
        except (KeyError, ValueError):
            issues.append(LintIssue(source, f"{fragment_key}: invalid trigger_type"))
            continue
        counts[trigger] = counts.get(trigger, 0) + 1

        tags = fragment.get("pillar_tags", [])
        if not isinstance(tags, list) or not tags:
            issues.append(
                LintIssue(
                    source,
                    f"{fragment_key}: pillar_tags must be a non-empty list",
                )
            )
            continue
        for tag in tags:
            if str(tag) not in pillar_keys:
                issues.append(
                    LintIssue(
                        source,
                        f"{fragment_key}: pillar {tag!r} is not in world {world.world_key}",
                    )
                )

        text = str(fragment.get("text", "")).strip()
        if not text:
            issues.append(LintIssue(source, f"{fragment_key}: empty text"))

    for trigger, minimum in MIN_POOL_BY_TRIGGER.items():
        actual = counts.get(trigger, 0)
        if actual < minimum:
            issues.append(
                LintIssue(
                    str(world.directory / "fragments"),
                    f"{trigger.value}: pool {actual} below minimum {minimum}",
                )
            )
    return issues


def _lint_cross_world_pillars(
    worlds: list[WorldContent],
    pillar_keys_by_world: dict[str, set[str]],
) -> list[LintIssue]:
    """A fragment may only reference pillars owned by its own world."""
    issues: list[LintIssue] = []
    for world in worlds:
        own = pillar_keys_by_world[world.world_key]
        foreign = {
            key
            for other_key, pillars in pillar_keys_by_world.items()
            if other_key != world.world_key
            for key in pillars
        }
        for fragment in world.fragments:
            tags = fragment.get("pillar_tags", [])
            if not isinstance(tags, list):
                continue
            for tag in tags:
                tag_s = str(tag)
                if tag_s not in own and tag_s in foreign:
                    issues.append(
                        LintIssue(
                            str(fragment.get("_source", world.directory)),
                            (
                                f"{fragment.get('fragment_key')}: "
                                f"pillar {tag_s!r} belongs to another world"
                            ),
                        )
                    )
    return issues


def _pillar_keys(pillars: list[dict[str, object]]) -> set[str]:
    return {
        str(pillar["key"]) for pillar in pillars if isinstance(pillar, dict) and "key" in pillar
    }


def _read_yaml(path: Path) -> object:
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)
