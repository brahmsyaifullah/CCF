# Task 02 — Security: Node.js Login API

## Context

A small Node.js/Express service authenticates users against a MySQL database. It was thrown
together quickly and is about to ship. Security review flagged it, but the team isn't sure
exactly what's wrong or how bad it is.

```js
// routes/auth.js
import express from "express";
import mysql from "mysql2/promise";
import jwt from "jsonwebtoken";

const app = express();
const pool = mysql.createPool({ host: "db", user: "app", password: process.env.DB_PASS, database: "app" });
const SECRET = process.env.JWT_SECRET;

app.get("/login", async (req, res) => {
  const user = req.query.username;
  const pw   = req.query.password;

  // look the user up
  const q = `SELECT * FROM users WHERE username='${user}' AND password='${pw}'`;
  const [rows] = await pool.query(q);

  if (rows.length) {
    const u = rows[0];
    if (u.password === pw) {                       // double-check the password
      return res.json({ token: jwt.sign({ id: u.id }, SECRET) });
    }
  }
  return res.status(401).send("invalid");
});

app.listen(3000);
```

## Task

You are the security engineer. Treat this as a real engagement:

1. **Enumerate every vulnerability**, ranked by severity. There are **at least three** —
   including a classic injection and a timing side-channel. For each: what it is, a concrete
   exploit, the impact, and the fix.
2. **Rewrite the endpoint** to be production-safe: parameterized queries, hashed passwords,
   constant-time comparison, and any other hardening you deem necessary. Show the corrected
   code.
3. Note anything that should be fixed *outside* this file (config, infra, headers, rate
   limiting, logging) — but don't hand-wave; say what and why.

## Grading criteria (0–10 each)

- **Correctness** — Fixes are real and complete: SQL injection closed via parameterization,
  passwords stored as hashes and compared constant-time, secrets handled correctly. No new
  bugs introduced.
- **Completeness** — All vulnerabilities found (injection, timing attack, plaintext password
  storage, likely missing rate limiting / TLS / secret hygiene), each with exploit + impact +
  fix. Rewritten code is runnable and covers the auth flow end to end.
- **Blind spots** — Did it catch the **timing attack** (`===` on secrets is not
  constant-time)? Error-message oracles (different responses for "no such user" vs "wrong
  password")? Logging the password? `GET` leaking credentials in URLs/logs? JWT algorithm /
  expiry issues? Account enumeration via timing? Mass-assignment? Did it recommend bcrypt/argon2
  and parameterized queries by name?
- **Code quality** — Idiomatic, uses a real hashing lib, input validation, clear structure,
  secrets from env not hardcoded, no `SELECT *` leaking password hashes to the app.
