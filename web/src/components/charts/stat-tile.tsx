export function StatTile({
  label,
  value,
  sub,
}: {
  label: string;
  value: string;
  sub?: string;
}) {
  return (
    <div className="border border-border rounded-xl bg-surface p-5">
      <p className="text-sm text-muted font-medium m-0">{label}</p>
      <p className="font-display text-3xl font-bold tracking-tight mt-1.5 mb-0 text-text">
        {value}
      </p>
      {sub && <p className="text-sm text-muted mt-1.5 mb-0">{sub}</p>}
    </div>
  );
}
