from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import CartoonStyle

# Starting-point parameters; values mirror docs/architecture/RENDERING_ENGINE.md §5 and are tuned on device.
DEFAULT_STYLES: list[dict] = [
    {
        "id": "original",
        "name": "Original",
        "sort_order": 0,
        "params": {},
    },
    {
        "id": "cel_pop",
        "name": "Cel Pop",
        "sort_order": 1,
        "params": {
            "smooth": {"radiusPx": 3.0, "rangeSigma": 0.12},
            "quantize": {"bands": 5, "softness": 0.08, "saturation": 1.3, "contrast": 1.1},
            "edges": {"mode": "sobel", "t0": 0.10, "t1": 0.25, "widthPx": 1.5, "strength": 0.9},
            "silhouette": {"widthPx": 2.0, "strength": 0.8},
        },
    },
    {
        "id": "ink_comic",
        "name": "Ink Comic",
        "sort_order": 2,
        "params": {
            "smooth": {"radiusPx": 2.5, "rangeSigma": 0.10},
            "quantize": {"bands": 4, "softness": 0.06, "saturation": 1.1, "contrast": 1.3},
            "edges": {"mode": "sobel", "t0": 0.08, "t1": 0.20, "widthPx": 2.5, "strength": 1.0},
            "halftone": {"cellPx": 6.0},
        },
    },
    {
        "id": "soft_pastel",
        "name": "Soft Pastel",
        "sort_order": 3,
        "params": {
            "smooth": {"radiusPx": 4.0, "rangeSigma": 0.15},
            "quantize": {"bands": 6, "softness": 0.18, "saturation": 0.9, "contrast": 0.95, "brightnessLift": 0.08},
            "edges": {"mode": "sobel", "t0": 0.14, "t1": 0.30, "widthPx": 1.0, "strength": 0.4},
        },
    },
    {
        "id": "noir_sketch",
        "name": "Noir Sketch",
        "sort_order": 4,
        "params": {
            "smooth": {"radiusPx": 2.0, "rangeSigma": 0.10},
            "quantize": {"bands": 4, "softness": 0.07, "saturation": 0.0, "contrast": 1.2},
            "edges": {"mode": "sobel", "t0": 0.07, "t1": 0.18, "widthPx": 2.0, "strength": 1.0},
            "hatching": {"spacingPx": 5.0},
        },
    },
]


async def seed_styles(session: AsyncSession) -> int:
    """Insert missing default styles. Existing rows are left untouched. Returns the number inserted."""
    existing = set((await session.scalars(select(CartoonStyle.id))).all())
    created = 0
    for style in DEFAULT_STYLES:
        if style["id"] in existing:
            continue
        session.add(CartoonStyle(version=1, enabled=True, **style))
        created += 1
    await session.commit()
    return created
