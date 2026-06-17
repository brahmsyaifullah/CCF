# Task 03 — Refactor: Python God Function

## Context

`process_order` started as a simple "save an order" function and accreted responsibilities
for years. It now validates input, computes pricing, applies discounts and coupons, figures
tax by region, decrements inventory, charges a payment gateway, sends a confirmation email,
and writes an audit log — all in one ~200-line function, with the logic interleaved and
duplicated. It's untestable, buggy (changes in one branch silently break another), and nobody
wants to touch it.

```python
# app/orders.py
import logging
import requests
from app.db import db
from app.models import Order, OrderItem, Inventory, Coupon
from app.mail import send_mail

log = logging.getLogger(__name__)

def process_order(customer, items, coupon_code, payment_token, ip):
    # ---- validate ----
    if not customer or not customer.get("email"):
        return {"ok": False, "error": "missing customer email"}
    if not items or not isinstance(items, list):
        return {"ok": False, "error": "no items"}
    if len(items) > 100:
        return {"ok": False, "error": "too many items"}
    for it in items:
        if not it.get("sku") or it.get("qty", 0) <= 0 or it.get("price", 0) < 0:
            return {"ok": False, "error": "bad item: %s" % it}

    # ---- price it ----
    subtotal = 0
    for it in items:
        subtotal += it["qty"] * it["price"]
    discount = 0
    if coupon_code:
        c = Coupon.query.filter_by(code=coupon_code).first()
        if c and c.active and c.uses < c.max_uses:
            if c.kind == "percent":
                discount = subtotal * (c.value / 100.0)
            elif c.kind == "fixed":
                discount = min(c.value, subtotal)
            if discount > subtotal:
                discount = subtotal
        # silently ignore invalid/expired coupons

    # ---- tax (by region, copied from a spreadsheet) ----
    region = customer.get("region", "US")
    if region == "US":
        rate = 0.07
    elif region == "EU":
        rate = 0.21
    elif region == "UK":
        rate = 0.20
    else:
        rate = 0.0
    taxable = subtotal - discount
    tax = round(taxable * rate, 2)

    # ---- inventory ----
    for it in items:
        inv = Inventory.query.filter_by(sku=it["sku"]).first()
        if not inv or inv.on_hand < it["qty"]:
            return {"ok": False, "error": "out of stock: %s" % it["sku"]}
    for it in items:
        inv = Inventory.query.filter_by(sku=it["sku"]).first()
        inv.on_hand -= it["qty"]
        db.session.add(inv)

    # ---- charge ----
    total = round(taxable + tax, 2)
    if total <= 0:
        return {"ok": False, "error": "zero total"}
    try:
        r = requests.post("https://pay.example.com/charge",
                          json={"token": payment_token, "amount": int(total * 100)},
                          timeout=10)
        if r.status_code != 200 or not r.json().get("ok"):
            return {"ok": False, "error": "payment failed"}
    except Exception as e:
        log.exception("payment error")
        return {"ok": False, "error": "payment error"}

    # ---- persist ----
    order = Order(customer_id=customer["id"], subtotal=subtotal, discount=discount,
                  tax=tax, total=total, region=region, ip=ip)
    db.session.add(order)
    db.session.flush()
    for it in items:
        db.session.add(OrderItem(order_id=order.id, sku=it["sku"], qty=it["qty"],
                                 price=it["price"]))
    db.session.commit()

    # ---- notify ----
    try:
        send_mail(customer["email"], "Order confirmed",
                  "Your order %s totalled %s" % (order.id, total))
    except Exception:
        log.exception("email failed")  # order already saved; swallow

    # ---- audit ----
    log.info("order processed id=%s customer=%s total=%s ip=%s", order.id, customer["id"], total, ip)
    return {"ok": True, "order_id": order.id, "total": total}
```

## Task

1. **Split `process_order` into cohesive, single-responsibility units** (validate → price →
   apply discount → tax → reserve inventory → charge → persist → notify → audit). Each unit
   should be independently testable. Preserve the existing public contract: same inputs, same
   return shape (`{"ok": ...}`), same observable side effects.
2. Identify and call out the **latent bugs and smells** the refactor should fix as it goes
   (there are several — e.g. tax hardcoded, coupons silently ignored, inventory checked then
   decremented in two passes, the payment charge vs. inventory reservation ordering, no
   transaction rollback on failure). Don't fix *everything* silently; list what you're
   preserving vs. improving.
3. **Add tests** for at least: a happy path, an out-of-stock failure, an invalid coupon, and
   a payment failure — with the external calls (payment gateway, mail) mocked.

## Grading criteria (0–10 each)

- **Correctness** — Refactored code preserves the original behavior on the happy path and
  the listed failure paths. No regression in the return contract. Tests pass and are green.
- **Completeness** — Every responsibility extracted into its own function/module; validation,
  pricing, discount, tax, inventory, payment, persistence, notification, and audit are all
   separated; the requested test cases are present and mocked appropriately.
- **Blind spots** — Did it spot the inventory **race** (check-then-decrement without a
  lock/`UPDATE … WHERE on_hand >= qty`)? The lack of a **transaction** around charge +
  persist + inventory (a payment success with a later DB failure = lost money)? Coupons
  silently failing? Hardcoded tax rates? Did it keep email failure non-fatal correctly?
- **Code quality** — Clear names, small functions, sensible module layout, dependency
  injection for the payment/mail gateways (so they're mockable), idiomatic Python, readable
  tests.
