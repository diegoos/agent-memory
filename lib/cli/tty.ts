/** TTY color + interactive select menus for the installer CLI. */
import type { SelectOption } from "./constants";

const ESC = "\u001b";
const CSI = `${ESC}[`;

export function isTTY(): boolean {
  return process.stdin.isTTY === true && process.stdout.isTTY === true;
}

export function useColor(): boolean {
  if (process.env.NO_COLOR !== undefined && process.env.NO_COLOR !== "") {
    return false;
  }
  if (process.env.FORCE_COLOR !== undefined && process.env.FORCE_COLOR !== "") {
    return process.env.FORCE_COLOR !== "0";
  }
  return process.stdout.isTTY === true;
}

const colorEnabled = useColor();

function wrap(code: string, text: string): string {
  if (!colorEnabled) return text;
  return `${CSI}${code}m${text}${CSI}0m`;
}

export const c = {
  bold: (t: string) => wrap("1", t),
  dim: (t: string) => wrap("2", t),
  cyan: (t: string) => wrap("36", t),
  green: (t: string) => wrap("32", t),
  yellow: (t: string) => wrap("33", t),
  red: (t: string) => wrap("31", t),
  magenta: (t: string) => wrap("35", t),
  boldCyan: (t: string) => wrap("1;36", t),
  boldGreen: (t: string) => wrap("1;32", t),
  boldMagenta: (t: string) => wrap("1;35", t),
};

function renderSelectLines(
  title: string,
  options: SelectOption<string>[],
  selected: number,
): string[] {
  const lines = [c.bold(title), ""];
  for (let i = 0; i < options.length; i++) {
    const active = i === selected;
    const prefix = active ? `${c.cyan("›")} ` : "  ";
    const label = active ? c.bold(options[i].label) : options[i].label;
    lines.push(`${prefix}${label}`);
  }
  lines.push("", c.dim("↑/↓ or j/k · Enter confirm · Ctrl+C/Esc cancel"));
  return lines;
}

function renderMultiSelectLines(
  title: string,
  options: SelectOption<string>[],
  cursor: number,
  checked: Set<number>,
): string[] {
  const lines = [c.bold(title), ""];
  for (let i = 0; i < options.length; i++) {
    const active = i === cursor;
    const box = checked.has(i) ? c.green("[x]") : "[ ]";
    const prefix = active ? `${c.cyan("›")} ` : "  ";
    const label = active ? c.bold(options[i].label) : options[i].label;
    lines.push(`${prefix}${box} ${label}`);
  }
  lines.push(
    "",
    c.dim("↑/↓ or j/k · Space toggle · Enter confirm · Ctrl+C/Esc cancel"),
  );
  return lines;
}

function clearRenderedLines(lineCount: number): void {
  for (let i = 0; i < lineCount; i++) {
    process.stdout.write(`${CSI}1A${CSI}2K`);
  }
}

type EscState = "normal" | "esc" | "csi" | "ss3";

function createRawMenuController(opts: {
  onAbort: () => void;
  onRedraw: () => void;
  onConfirm: () => void;
  onUp: () => void;
  onDown: () => void;
  onSpace?: () => void;
}): { start: () => void; cleanup: () => void } {
  let escState: EscState = "normal";
  let escTimer: ReturnType<typeof setTimeout> | null = null;
  let rawModeEnabled = false;
  const stdin = process.stdin;

  function disableRawMode(): void {
    if (rawModeEnabled && typeof stdin.setRawMode === "function") {
      stdin.setRawMode(false);
      rawModeEnabled = false;
    }
  }

  function clearEscTimer(): void {
    if (escTimer) {
      clearTimeout(escTimer);
      escTimer = null;
    }
  }

  function isCsiFinal(ch: string): boolean {
    const code = ch.charCodeAt(0);
    return code >= 0x40 && code <= 0x7e;
  }

  function isAlphanumeric(ch: string): boolean {
    return /[0-9A-Za-z]/.test(ch);
  }

  function startEscTimer(): void {
    clearEscTimer();
    escTimer = setTimeout(() => {
      escTimer = null;
      if (escState === "esc") {
        escState = "normal";
        opts.onAbort();
        return;
      }
      if (escState === "csi" || escState === "ss3") {
        escState = "normal";
      }
    }, 50);
  }

  function cleanup(): void {
    clearEscTimer();
    disableRawMode();
    stdin.pause();
    stdin.removeListener("data", onData);
    stdin.removeListener("end", onEnd);
  }

  function processChar(ch: string): void {
    if (escState === "esc") {
      clearEscTimer();
      if (ch === "[") {
        escState = "csi";
        startEscTimer();
        return;
      }
      if (ch === "O") {
        escState = "ss3";
        startEscTimer();
        return;
      }
      if (isAlphanumeric(ch)) {
        escState = "normal";
      } else {
        escState = "normal";
        opts.onAbort();
        return;
      }
    }

    if (escState === "csi") {
      if (!isCsiFinal(ch)) {
        startEscTimer();
        return;
      }
      clearEscTimer();
      escState = "normal";
      if (ch === "A") {
        opts.onUp();
        return;
      }
      if (ch === "B") {
        opts.onDown();
        return;
      }
      return;
    }

    if (escState === "ss3") {
      if (!isCsiFinal(ch)) {
        startEscTimer();
        return;
      }
      clearEscTimer();
      escState = "normal";
      if (ch === "A") {
        opts.onUp();
        return;
      }
      if (ch === "B") {
        opts.onDown();
        return;
      }
      return;
    }

    if (ch === "\u0003") {
      opts.onAbort();
      return;
    }
    if (ch === ESC) {
      escState = "esc";
      startEscTimer();
      return;
    }
    if (ch === "k") {
      opts.onUp();
      return;
    }
    if (ch === "j") {
      opts.onDown();
      return;
    }
    if (ch === " " && opts.onSpace) {
      opts.onSpace();
      return;
    }
    if (ch === "\r" || ch === "\n") {
      opts.onConfirm();
    }
  }

  function onData(chunk: string): void {
    for (let i = 0; i < chunk.length; i++) {
      processChar(chunk[i]);
    }
  }

  function onEnd(): void {
    opts.onAbort();
  }

  function start(): void {
    let setupComplete = false;
    try {
      if (typeof stdin.setRawMode === "function") {
        stdin.setRawMode(true);
        rawModeEnabled = true;
      }
      stdin.resume();
      stdin.setEncoding("utf8");
      stdin.on("data", onData);
      stdin.on("end", onEnd);
      opts.onRedraw();
      setupComplete = true;
    } finally {
      if (!setupComplete) {
        disableRawMode();
      }
    }
  }

  return { start, cleanup };
}

/**
 * Interactive single-select menu (TTY only). Returns the chosen option value.
 * Aborts with exit 1 on Ctrl+C or Esc.
 */
export function selectPrompt<T extends string>(
  title: string,
  options: SelectOption<T>[],
): Promise<T> {
  return new Promise((resolve) => {
    let selected = 0;
    let renderedLineCount = 0;
    let controller: ReturnType<typeof createRawMenuController>;

    function abort(): void {
      controller.cleanup();
      process.stdout.write("\n");
      process.exit(1);
    }

    function printMenu(): void {
      const lines = renderSelectLines(title, options, selected);
      lines.forEach((line) => process.stdout.write(`${line}\n`));
      renderedLineCount = lines.length;
    }

    function redraw(): void {
      clearRenderedLines(renderedLineCount);
      printMenu();
    }

    controller = createRawMenuController({
      onAbort: abort,
      onRedraw: printMenu,
      onUp: () => {
        selected = (selected - 1 + options.length) % options.length;
        redraw();
      },
      onDown: () => {
        selected = (selected + 1) % options.length;
        redraw();
      },
      onConfirm: () => {
        controller.cleanup();
        process.stdout.write("\n");
        resolve(options[selected].value);
      },
    });
    controller.start();
  });
}

/**
 * Multi-select checkbox menu. Space toggles; Enter confirms (≥1 required).
 */
export function multiSelectPrompt<T extends string>(
  title: string,
  options: SelectOption<T>[],
): Promise<T[]> {
  return new Promise((resolve) => {
    let cursor = 0;
    const checked = new Set<number>();
    let renderedLineCount = 0;
    let hint = "";
    let controller: ReturnType<typeof createRawMenuController>;

    function abort(): void {
      controller.cleanup();
      process.stdout.write("\n");
      process.exit(1);
    }

    function printMenu(): void {
      const lines = renderMultiSelectLines(title, options, cursor, checked);
      if (hint) lines.push(c.yellow(hint));
      lines.forEach((line) => process.stdout.write(`${line}\n`));
      renderedLineCount = lines.length;
    }

    function redraw(): void {
      clearRenderedLines(renderedLineCount);
      printMenu();
    }

    controller = createRawMenuController({
      onAbort: abort,
      onRedraw: printMenu,
      onUp: () => {
        cursor = (cursor - 1 + options.length) % options.length;
        hint = "";
        redraw();
      },
      onDown: () => {
        cursor = (cursor + 1) % options.length;
        hint = "";
        redraw();
      },
      onSpace: () => {
        if (checked.has(cursor)) checked.delete(cursor);
        else checked.add(cursor);
        hint = "";
        redraw();
      },
      onConfirm: () => {
        if (checked.size === 0) {
          hint = "Select at least one harness (Space), then Enter.";
          redraw();
          return;
        }
        controller.cleanup();
        process.stdout.write("\n");
        const values = [...checked]
          .sort((a, b) => a - b)
          .map((i) => options[i].value);
        resolve(values);
      },
    });
    controller.start();
  });
}
