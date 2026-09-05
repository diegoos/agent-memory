/** Compare npm-style semver (optional prerelease). Returns -1 if a<b, 0 if equal, 1 if a>b. */

type Ident = string | number;

type Parsed = {
  major: number;
  minor: number;
  patch: number;
  pre: Ident[] | null;
};

const SEMVER =
  /^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/;

function parseIdents(pre: string): Ident[] {
  return pre
    .split(".")
    .map((part) => (/^[0-9]+$/.test(part) ? Number(part) : part));
}

function parseSemver(v: string): Parsed {
  const m = v.trim().match(SEMVER);
  if (!m) {
    const bits = v.split(".").map((n) => parseInt(n, 10) || 0);
    return {
      major: bits[0] ?? 0,
      minor: bits[1] ?? 0,
      patch: bits[2] ?? 0,
      pre: null,
    };
  }
  return {
    major: Number(m[1]),
    minor: Number(m[2]),
    patch: Number(m[3]),
    pre: m[4] ? parseIdents(m[4]) : null,
  };
}

function compareIdents(a: Ident, b: Ident): -1 | 0 | 1 {
  const aNum = typeof a === "number";
  const bNum = typeof b === "number";
  if (aNum && bNum) {
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
  }
  if (aNum && !bNum) return -1;
  if (!aNum && bNum) return 1;
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

function comparePre(a: Ident[] | null, b: Ident[] | null): -1 | 0 | 1 {
  if (a === null || b === null) {
    if (a === null && b === null) return 0;
    if (a !== null) return -1;
    return 1;
  }
  const n = Math.max(a.length, b.length);
  for (let i = 0; i < n; i++) {
    if (i >= a.length) return -1;
    if (i >= b.length) return 1;
    const c = compareIdents(a[i] as Ident, b[i] as Ident);
    if (c !== 0) return c;
  }
  return 0;
}

export function compareSemver(a: string, b: string): -1 | 0 | 1 {
  const pa = parseSemver(a);
  const pb = parseSemver(b);
  if (pa.major !== pb.major) return pa.major < pb.major ? -1 : 1;
  if (pa.minor !== pb.minor) return pa.minor < pb.minor ? -1 : 1;
  if (pa.patch !== pb.patch) return pa.patch < pb.patch ? -1 : 1;
  return comparePre(pa.pre, pb.pre);
}
