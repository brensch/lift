import { useTimer } from "../hooks/useTimer";
import { formatDuration } from "../lib/utils";

interface RestTimerProps {
  restUntil: Date;
}

export function RestTimer({ restUntil }: RestTimerProps) {
  const { getRemainingSeconds } = useTimer();
  const remaining = getRemainingSeconds(restUntil);

  if (remaining <= 0) return null;

  return (
    <div className="rounded-lg border-2 border-orange-300 bg-orange-50 p-4 text-center">
      <p className="text-sm text-orange-600">Rest</p>
      <p className="text-3xl font-mono font-bold text-orange-700">
        {formatDuration(remaining)}
      </p>
    </div>
  );
}
