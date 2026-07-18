export interface ParsedArgs {
  command?: string;
  values: Map<string, string>;
  flags: Set<string>;
}

export function parseArgs(argv: string[]): ParsedArgs {
  const [command, ...rest] = argv;
  const values = new Map<string, string>();
  const flags = new Set<string>();
  for (let index = 0; index < rest.length; index += 1) {
    const current = rest[index];
    if (!current?.startsWith("--")) continue;
    const key = current.slice(2);
    const next = rest[index + 1];
    if (next !== undefined && !next.startsWith("--")) {
      values.set(key, next);
      index += 1;
    } else {
      flags.add(key);
    }
  }
  return { ...(command === undefined ? {} : { command }), values, flags };
}

export function required(args: ParsedArgs, key: string): string {
  const value = args.values.get(key);
  if (!value) throw new Error(`Missing required option --${key}`);
  return value;
}
