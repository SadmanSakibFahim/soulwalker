from __future__ import annotations

from pathlib import Path

from soulwalker.domain.terminology import (
    REQUIRED_TERM_KEYS,
    MissingTermError,
    TermKey,
    resolve_term,
)
from soulwalker.services.content_lint import lint_content


def test_resolve_term_returns_value() -> None:
    table = {TermKey.CHECKPOINT_NAME.value: "a Held Breath"}
    assert resolve_term(table, TermKey.CHECKPOINT_NAME) == "a Held Breath"


def test_resolve_term_missing_raises() -> None:
    try:
        resolve_term({}, TermKey.PLAYER_TITLE)
    except MissingTermError as exc:
        assert str(exc) == "'PLAYER_TITLE'"
    else:
        raise AssertionError("expected MissingTermError")


def test_required_keys_cover_v1_screens() -> None:
    assert "CHECKPOINT_NAME" in REQUIRED_TERM_KEYS
    assert "DEATH_MARKER_NAME" in REQUIRED_TERM_KEYS
    assert "SUMMONS_NAME" in REQUIRED_TERM_KEYS
    assert "STANDINGS_NAME" in REQUIRED_TERM_KEYS


def test_packaged_endless_paralysis_lints_clean() -> None:
    repo_root = Path(__file__).resolve().parents[3]
    issues = lint_content(repo_root / "content")
    assert issues == []
