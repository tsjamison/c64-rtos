#!/usr/bin/env python3
"""Tokenize a lowercase C64 BASIC V2 listing (VS64 style, {name} control
codes) into a .prg loadable at $0801.

usage: bas2prg.py in.bas out.prg     (also: --check in.bas to list errors)
"""
import re
import sys

TOKENS = ["end", "for", "next", "data", "input#", "input", "dim", "read",
          "let", "goto", "run", "if", "restore", "gosub", "return", "rem",
          "stop", "on", "wait", "load", "save", "verify", "def", "poke",
          "print#", "print", "cont", "list", "clr", "cmd", "sys", "open",
          "close", "get", "new", "tab(", "to", "fn", "spc(", "then", "not",
          "step", "+", "-", "*", "/", "^", "and", "or", ">", "=", "<", "sgn",
          "int", "abs", "usr", "fre", "pos", "sqr", "rnd", "log", "exp",
          "cos", "sin", "tan", "atn", "peek", "len", "str$", "val", "asc",
          "chr$", "left$", "right$", "mid$", "go"]
CODES = {"clr": 147, "home": 19, "rvon": 18, "rvof": 146, "down": 17,
         "up": 145, "left": 157, "right": 29, "blk": 144, "wht": 5,
         "red": 28, "cyn": 159, "pur": 156, "grn": 30, "blu": 31, "yel": 158}


def petscii(ch):
    o = ord(ch)
    if "a" <= ch <= "z":
        return o - 32          # unshifted letters $41-$5a
    if "A" <= ch <= "Z":
        return o + 128         # shifted letters $c1-$da
    if 32 <= o < 96 or ch in "[]{}":
        return o
    raise ValueError("no petscii for %r" % ch)


def code_at(text, i):
    """(petscii value, end index) for a {name} or {nnn} code at text[i]."""
    j = text.find("}", i)
    if j < 0:
        return None
    name = text[i + 1:j]
    if name in CODES:
        return CODES[name], j + 1
    if name.isdigit() and int(name) < 256:
        return int(name), j + 1
    return None


def expand(text):
    """Split text into a list of PETSCII codes, expanding {name} codes."""
    out, i = [], 0
    while i < len(text):
        c = code_at(text, i) if text[i] == "{" else None
        if c:
            out.append(("raw", c[0]))
            i = c[1]
        else:
            out.append(("chr", text[i]))
            i += 1
    return out


def crunch(body):
    """Tokenize one line. Like VS64, {codes} inside a REM stay literal."""
    res, i, quote, raw = [], 0, False, False
    while i < len(body):
        ch = body[i]
        if ch == "{" and raw != "rem":
            c = code_at(body, i)
            if c:
                res.append(c[0])
                i = c[1]
                continue
        if ch == '"':
            quote = not quote
        if quote or raw:
            if raw == "data" and ch == ":" and not quote:
                raw = False
            res.append(petscii(ch))
            i += 1
            continue
        for n, tok in enumerate(TOKENS):
            if body.startswith(tok, i):
                res.append(0x80 + n)
                i += len(tok)
                if tok in ("rem", "data"):
                    raw = tok
                break
        else:
            res.append(petscii(ch))
            i += 1
    return res


def build(src):
    lines, errors, last = [], [], -1
    for ln, text in enumerate(src.splitlines(), 1):
        if not text.strip():
            continue
        m = re.match(r"\s*(\d+)\s?(.*)$", text)
        if m:
            num, body = int(m.group(1)), m.group(2)
        else:                       # VS64: an unnumbered line is last + 1
            num, body = last + 1, text.strip()
        if num <= last:
            errors.append("%d: line %d out of order" % (ln, num))
        last = num
        screen_len = len(str(num)) + 1 + len(expand(body))
        if screen_len > 80:
            errors.append("%d: line %d is %d chars (>80)" % (ln, num, screen_len))
        if body.count('"') % 2:
            errors.append("%d: line %d has an odd number of quotes" % (ln, num))
        tok = crunch(body)
        if len(tok) > 250:
            errors.append("%d: line %d too long tokenized" % (ln, num))
        lines.append((num, tok))
    addr, prg = 0x0801, bytearray([0x01, 0x08])
    for num, tok in lines:
        nxt = addr + 4 + len(tok) + 1
        prg += bytes([nxt & 255, nxt >> 8, num & 255, num >> 8]) + bytes(tok) + b"\0"
        addr = nxt
    prg += b"\0\0"
    return prg, errors


def detokenize(prg):
    out, p = [], 2
    while True:
        link = prg[p] | prg[p + 1] << 8
        if link == 0:
            return "\n".join(out)
        num = prg[p + 2] | prg[p + 3] << 8
        p += 4
        s, quote = "", False
        while prg[p]:
            b = prg[p]
            if b == 34:
                quote = not quote
            s += TOKENS[b - 0x80] if not quote and b >= 0x80 and b - 0x80 < len(TOKENS) else (
                chr(b + 32) if 0x41 <= b <= 0x5a else chr(b) if 32 <= b < 96 else "{%d}" % b)
            p += 1
        p += 1
        out.append("%d %s" % (num, s))


if __name__ == "__main__":
    if sys.argv[1] == "--check":
        _, errs = build(open(sys.argv[2]).read())
        print("\n".join(errs) or "ok")
        sys.exit(1 if errs else 0)
    data, errs = build(open(sys.argv[1]).read())
    for e in errs:
        print(sys.argv[1] + ":" + e, file=sys.stderr)
    open(sys.argv[2], "wb").write(data)
    sys.exit(1 if errs else 0)
