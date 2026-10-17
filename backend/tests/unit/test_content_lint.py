from __future__ import annotations

from pathlib import Path

from soulwalker.services.content_lint import lint_content


def _write_world(
    root: Path,
    *,
    pillar: str = "the_weight",
    extra_term: dict[str, str] | None = None,
) -> None:
    world_dir = root / "worlds" / "fixture"
    fragments = world_dir / "fragments"
    fragments.mkdir(parents=True)
    (world_dir / "world.yaml").write_text(
        "\n".join(
            [
                "world_key: w_fixture",
                "name: Fixture",
                "tone: test",
                "art_theme: test_palette",
                "active: true",
                "pillars:",
                f"  - key: {pillar}",
                "    sort_order: 1",
                "",
            ]
        ),
        encoding="utf-8",
    )
    terms = {
        "PLAYER_TITLE": "t",
        "CHECKPOINT_NAME": "c",
        "DEATH_MARKER_NAME": "d",
        "AFFLICTION_NAME": "a",
        "ARMAMENT_CATEGORY_WEAPON": "w",
        "ARMAMENT_CATEGORY_ARMOR": "r",
        "BOSS_ENCOUNTER_LABEL": "b",
        "SUMMONS_NAME": "s",
        "STANDINGS_NAME": "n",
    }
    if extra_term:
        terms.update(extra_term)
    (world_dir / "terminology.yaml").write_text(
        "\n".join(f"{key}: {value}" for key, value in terms.items()) + "\n",
        encoding="utf-8",
    )
    (fragments / "daily_ambient.yaml").write_text(
        "\n".join(
            [
                "- fragment_key: f_x_001",
                "  pillar_tags: [the_foreign_pillar]",
                "  rarity_weight: 1",
                "  text: leak",
                "",
            ]
        ),
        encoding="utf-8",
    )


def test_missing_term_is_reported(tmp_path: Path) -> None:
    _write_world(tmp_path)
    (tmp_path / "worlds" / "fixture" / "terminology.yaml").write_text(
        "PLAYER_TITLE: t\n",
        encoding="utf-8",
    )
    issues = lint_content(tmp_path)
    messages = [issue.message for issue in issues]
    assert any("missing term CHECKPOINT_NAME" in message for message in messages)


def test_foreign_pillar_tag_is_reported(tmp_path: Path) -> None:
    _write_world(tmp_path, pillar="the_weight")
    issues = lint_content(tmp_path)
    messages = [issue.message for issue in issues]
    assert any("the_foreign_pillar" in message for message in messages)


def test_small_pool_is_reported(tmp_path: Path) -> None:
    _write_world(tmp_path)
    issues = lint_content(tmp_path)
    messages = [issue.message for issue in issues]
    assert any("daily_ambient: pool" in message for message in messages)
