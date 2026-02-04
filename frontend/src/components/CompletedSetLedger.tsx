import type {
  CompletedSet,
  ProposedSet,
} from "../gen/lift/v1/workout_pb.js";
import { exerciseName } from "../lib/utils";

interface CompletedSetLedgerProps {
  completedSets: CompletedSet[];
  proposedSets: ProposedSet[];
}

export function CompletedSetLedger({
  completedSets,
  proposedSets,
}: CompletedSetLedgerProps) {
  const donesets = completedSets.filter((cs) => cs.endedAt != null);
  if (donesets.length === 0) return null;

  const proposedMap = new Map(proposedSets.map((ps) => [ps.id, ps]));

  return (
    <div className="rounded-lg border bg-white">
      <h3 className="border-b px-3 py-2 text-sm font-semibold">
        Completed Sets
      </h3>
      <div className="divide-y">
        {donesets.map((cs) => {
          const proposed = proposedMap.get(cs.proposedSetId);
          return (
            <div key={cs.id} className="flex items-center justify-between px-3 py-2 text-sm">
              <span>{proposed ? exerciseName(proposed.exercise) : "?"}</span>
              <span className="text-gray-600">
                {cs.actualReps} x {cs.actualWeight}kg
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
