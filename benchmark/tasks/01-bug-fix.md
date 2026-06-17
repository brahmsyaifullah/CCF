# Task 01 — Bug Fix: Python Pagination

## Context

A Flask-backed admin dashboard lists orders in pages. Users have reported two symptoms that
support can reproduce but can't fully explain:

1. **Every page shows one extra row** — the last item on page *N* is the same as the first
   item on page *N+1* (an overlapping/duplicate row at the boundary).
2. **Occasional 500 errors** — the page "just crashes" for some users, *only* when they
   arrive via a certain bookmarked URL; refreshing sometimes fixes it.

The pagination helper and its caller look like this:

```python
# app/pagination.py
def paginate(items, page, page_size=20):
    """Return one page of `items`. `page` is 1-indexed."""
    start = (page - 1) * page_size
    end = page * page_size + 1          # +1 so we "always see the next item"
    return items[start:end]


# app/views.py
from flask import request, jsonify
from app.pagination import paginate
from app.models import Order

@app.get("/orders")
def list_orders():
    page = request.args.get("page", 1)          # <-- comes from the query string
    size = request.args.get("page_size", 20)
    rows = Order.query.order_by(Order.created_at.desc()).all()
    page_items = paginate(rows, page, int(size))
    return jsonify([r.to_dict() for r in page_items])
```

## Task

1. **Identify and fix every bug** in `paginate` / `list_orders`. There are (at least) **two
   distinct defects** — one obvious, one hidden. Explain the root cause of each.
2. Make the boundary behavior correct: page *N* and page *N+1* must never overlap, and no
   rows may be silently dropped.
3. Harden the function so invalid input can't crash the endpoint: handle non-integer /
   out-of-range `page` and `page_size` gracefully (return an empty page or a clear error,
   your call — justify it).
4. Add tests covering: the boundary between two pages, page 1, a page past the end,
   non-integer input, and `page_size` of 1.

## Grading criteria (0–10 each)

- **Correctness** — Both bugs fixed; pagination math is exact (no overlap, no drops); the
  off-by-one and the type-coercion crash are both gone. Boundary tests pass.
- **Completeness** — Addresses *both* defects (not just the visible off-by-one), plus input
  validation, plus tests for every case listed above. No requirement skipped.
- **Blind spots** — Did it catch the **hidden** type-coercion bug (str `page` from
  `request.args`)? Did it consider negative/zero `page`, empty `items`, very large
  `page_size`, and the performance of slicing a huge ORM list? Did it note that the `+1`
  "trick" was load-more/has-next logic done wrong?
- **Code quality** — Clean, idiomatic, reusable (e.g. a small result dataclass or a
  `has_next` flag rather than magic +1), tests are readable and well-named.
