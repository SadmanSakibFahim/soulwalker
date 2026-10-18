from __future__ import annotations

from soulwalker.dev.router import DEV_DISPLAY_NAME, router


def test_dev_router_is_isolated_under_v1_dev() -> None:
    assert router.prefix == "/v1/dev"
    assert DEV_DISPLAY_NAME == "devwalker"
    paths = {getattr(route, "path", "") for route in router.routes}
    assert "/v1/dev/close-day" in paths
    assert "/v1/dev/set-streak" not in paths
