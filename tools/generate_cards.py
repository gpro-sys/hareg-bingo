#!/usr/bin/env python3
"""Generate the Hareg Bingo pre-generated card library.

Produces an exact replica of the shipped asset layout from the reference
application (flat row-major array of 24 numbers per card, center FREE cell
omitted, unique cartela_no 1..20000, matching-letter columns).

Layout reminder (25 cells, index 12 = FREE):
    [ 0  1  2  3  4 ]
    [ 5  6  7  8  9 ]
    [10 11  FREE 13 14]
    [15 16 17 18 19]
    [20 21 22 23 24]

Columns of the card map to B ingo letters:
    column 0 -> indices [0, 5, 10, 15, 20]  range 1..15  (B)
    column 1 -> indices [1, 6, 11, 16, 21]  range 16..30 (I)
    column 2 -> indices [2, 7, 12, 17, 22]  range 31..45 (N)
    column 3 -> indices [3, 8, 13, 18, 23]  range 46..60 (G)
    column 4 -> indices [4, 9, 14, 19, 24]  range 61..75 (O)
"""

import argparse
import json
import random
import sys
from pathlib import Path

TOTAL_CARDS = 20_000
CENTER = 12

# Flat 25-cell layout -> indices per letter column.
COLUMN_INDEXES = [
    [0, 5, 10, 15, 20],
    [1, 6, 11, 16, 21],
    [2, 7, CENTER, 17, 22],
    [3, 8, 13, 18, 23],
    [4, 9, 14, 19, 24],
]


def _column_low(letter_index: int) -> int:
    """Inclusive lowest value on the letter's 1..75 pool."""
    return letter_index * 15 + 1


def make_card(cartela_no: int, rng: random.Random) -> dict:
    """Build one card dict using the reference JSON schema keys."""
    # NOTE: same key ordering as the shipped asset (id, cartela_no, bingo_numbers).
    grid = [0] * 25
    for letter in range(5):
        low = _column_low(letter)
        pool = list(range(low, low + 15))
        rng.shuffle(pool)
        picks = pool[:5]
        # Only column 2 (letter "N") loses a cell, and that cell is exactly the
        # centre of the 5x5 layout. Every other letter keeps five picks.
        filled = COLUMN_INDEXES[letter]
        cells = [cell for i, cell in enumerate(filled) if i != CENTER]
        for cell, value in zip(cells, picks):
            grid[cell] = value

    numbers = [value for i, value in enumerate(grid) if i != CENTER]
    return {"id": cartela_no, "cartela_no": cartela_no, "bingo_numbers": numbers}


def _column_range(letter: int) -> tuple[int, int]:
    low = _column_low(letter)
    return low, low + 14


def generate(total: int, seed: int) -> list[dict]:
    rng = random.Random(seed)
    return [make_card(cartela_no, rng) for cartela_no in range(1, total + 1)]


def validate(cards: list[dict]) -> None:
    if len(cards) != TOTAL_CARDS:
        raise ValueError(f"expected {TOTAL_CARDS} cards, produced {len(cards)}")
    seen: set[int] = set()
    for card in cards:
        cartela = card["cartela_no"]
        if cartela in seen:
            raise ValueError(f"duplicate cartela_no {cartela}")
        seen.add(cartela)
        numbers = card["bingo_numbers"]
        if len(numbers) != 24:
            raise ValueError(f"card {cartela} has {len(numbers)} numbers")
        if 0 in numbers:
            raise ValueError(f"card {cartela} lost its FREE slot")
        # Index 12 in the 25-cell layout is FREE, so numbers with an index
        # of 12 in the flat (centre-omitted) array sits right after index 11.
        # After "insert FREE", column 2 has 4 numbers while every other
        # column has 5. See make_card for the exact mapping.
        for letter, column in enumerate(COLUMN_INDEXES):
            low, high = _column_range(letter)
            count = 0
            for cell in column:
                if cell == CENTER:
                    continue
                value = numbers[cell if cell < CENTER else cell - 1]
                if value != 0:
                    count += 1
                    if not low <= value <= high:
                        raise ValueError(
                            f"card {cartela} value {value} belongs "
                            f"outside column {letter}",
                        )
            expected_count = 4 if letter == 2 else 5
            if count != expected_count:
                raise ValueError(
                    f"card {cartela} column {letter} has {count} "
                    f"numbers, expected {expected_count}",
                )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261105)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    cards = generate(TOTAL_CARDS, args.seed)
    validate(cards)

    # Byte compact output keeps the asset small on device.
    payload = json.dumps(cards, separators=(",", ":"))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(payload, encoding="utf-8")
    size = args.out.stat().st_size
    if not args.quiet:
        print(f"wrote {len(cards):,} cards ({size:,} bytes) to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
