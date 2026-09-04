import { describe, expect, test } from "bun:test";
import { compareSemver } from "../src/semver";

describe("compareSemver", () => {
  test("orders core versions", () => {
    expect(compareSemver("0.2.0", "0.2.1")).toBe(-1);
    expect(compareSemver("0.2.1", "0.2.0")).toBe(1);
    expect(compareSemver("0.2.0", "0.2.0")).toBe(0);
  });

  test("prerelease is less than the same core", () => {
    expect(compareSemver("0.2.1-rc.0", "0.2.1")).toBe(-1);
    expect(compareSemver("0.2.1", "0.2.1-rc.0")).toBe(1);
  });

  test("prerelease is greater than the previous core", () => {
    expect(compareSemver("0.2.1-rc.0", "0.2.0")).toBe(1);
  });

  test("orders prerelease identifiers", () => {
    expect(compareSemver("0.2.1-rc.0", "0.2.1-rc.1")).toBe(-1);
    expect(compareSemver("0.2.1-rc.0", "0.2.1-rc.0")).toBe(0);
  });
});
