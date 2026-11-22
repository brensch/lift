/** A lift's name when nothing names it: its key made readable
 *  (`zercher_squat` → "Zercher Squat"). The API sends every lift's name from
 *  the person's program; this is only the fallback. */
export function exerciseName(key: string, name?: string): string {
  if (name) return name;
  if (!key) return "Unknown";
  return key
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}
