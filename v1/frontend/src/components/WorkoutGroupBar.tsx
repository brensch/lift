import { useState, useEffect } from "react";
import { useWorkout } from "@/context/WorkoutContext";
import { useUser } from "@/context/UserContext";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import { UserPlus, Users, Clock, Dumbbell, LogOut, ArrowRight } from "lucide-react";
import { type GroupSessionMember, type NextUp, Exercise } from "@/lib/api";
import { MemberWorkoutModal } from "./MemberWorkoutModal";

// Helper to format seconds as MM:SS
function formatTime(seconds: number): string {
  const absSeconds = Math.abs(Math.floor(seconds));
  const mins = Math.floor(absSeconds / 60);
  const secs = absSeconds % 60;
  const sign = seconds < 0 ? "-" : "";
  return `${sign}${mins}:${secs.toString().padStart(2, "0")}`;
}

// Helper to get exercise name
function getExerciseName(exercise: Exercise): string {
  const names: Record<number, string> = {
    [Exercise.SQUAT]: "Squat",
    [Exercise.BENCH]: "Bench",
    [Exercise.DEADLIFT]: "Deadlift",
    [Exercise.OHP]: "OHP",
    [Exercise.ROW]: "Row",
  };
  return names[exercise] || "Unknown";
}

// Session member card with realtime updates
function SessionMemberCard({ member, onClick }: { member: GroupSessionMember; onClick?: () => void }) {
  const [now, setNow] = useState(new Date());

  // Update time every second for realtime countdown
  useEffect(() => {
    const interval = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(interval);
  }, []);

  const activity = member.currentActivity;
  const completedCount = member.completedSets?.length ?? 0;
  const remainingCount = member.remainingSets?.length ?? 0;
  const totalSets = completedCount + remainingCount;

  // Calculate realtime status from activity
  let statusText = "Idle";
  let statusColor = "text-muted-foreground";
  let timeDisplay = "";

  if (activity && activity.startedAt) {
    const activityStart = activity.startedAt.toDate();
    const elapsedMs = now.getTime() - activityStart.getTime();
    const elapsedSeconds = elapsedMs / 1000;

    if (activity.type === "set") {
      statusText = `${getExerciseName(activity.exercise)} #${activity.setNumber}`;
      statusColor = "text-yellow-600";
      timeDisplay = formatTime(elapsedSeconds);
    } else if (activity.type === "rest") {
      // Server sends restSecondsRemaining which was calculated at send time
      // We approximate by using the startedAt and assuming a 3min rest
      const assumedPlannedRest = 180; // 3 minutes
      const currentRemaining = assumedPlannedRest - elapsedSeconds;

      if (currentRemaining > 0) {
        statusText = "Resting";
        statusColor = "text-blue-500";
        timeDisplay = formatTime(currentRemaining);
      } else {
        statusText = "Chat time";
        statusColor = "text-orange-500";
        timeDisplay = "+" + formatTime(Math.abs(currentRemaining));
      }
    }
  }

  return (
    <Card
      className={`p-3 min-w-[120px] ${onClick ? "cursor-pointer hover:bg-accent transition-colors" : ""}`}
      onClick={onClick}
    >
      <div className="flex flex-col gap-1">
        <div className="flex items-center justify-between">
          <span className="font-medium text-sm truncate">
            {member.userId}
          </span>
          {member.isConnected && (
            <span className="w-2 h-2 rounded-full bg-green-500" title="Connected" />
          )}
        </div>

        {/* Progress indicator */}
        {totalSets > 0 && (
          <div className="flex items-center gap-1 text-xs text-muted-foreground">
            <Dumbbell className="h-3 w-3" />
            <span>{completedCount}/{totalSets}</span>
          </div>
        )}

        <div className={`text-xs ${statusColor}`}>
          {statusText}
        </div>

        {timeDisplay && (
          <div className={`flex items-center gap-1 text-xs ${statusColor}`}>
            <Clock className="h-3 w-3" />
            <span>{timeDisplay}</span>
          </div>
        )}
      </div>
    </Card>
  );
}

// Next Up banner showing who should go next
function NextUpBanner({ nextUp, currentUsername }: { nextUp: NextUp; currentUsername: string }) {
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    const interval = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(interval);
  }, []);

  const isMe = nextUp.userId === currentUsername;
  const displayName = isMe ? "You" : nextUp.userId;

  // Calculate countdown based on rest start time if available
  let secondsUntilReady = 0;
  if (nextUp.restStartedAt && nextUp.plannedRestSeconds > 0) {
    const restStartTime = nextUp.restStartedAt.toDate();
    const elapsedSeconds = (now.getTime() - restStartTime.getTime()) / 1000;
    secondsUntilReady = Math.max(0, nextUp.plannedRestSeconds - elapsedSeconds);
  } else {
    // Fallback to server-provided value (won't count down but better than nothing)
    secondsUntilReady = Math.max(0, nextUp.secondsUntilReady);
  }

  const isReady = secondsUntilReady <= 0;

  return (
    <Card className={`p-3 ${isMe ? "bg-primary/10 border-primary/30" : "bg-muted/50"}`}>
      <div className="flex items-center gap-3">
        <ArrowRight className={`h-5 w-5 ${isReady ? "text-green-500" : "text-muted-foreground"}`} />
        <div className="flex-1">
          <div className="text-sm font-medium">
            Next Up: {displayName}
          </div>
          <div className="text-xs text-muted-foreground">
            {getExerciseName(nextUp.exercise)} @ {nextUp.weight}kg - Set #{nextUp.setNumber}
          </div>
        </div>
        {!isReady && (
          <div className="flex items-center gap-1 text-sm text-muted-foreground">
            <Clock className="h-4 w-4" />
            <span>{formatTime(secondsUntilReady)}</span>
          </div>
        )}
        {isReady && (
          <span className="text-sm font-medium text-green-600">Ready!</span>
        )}
      </div>
    </Card>
  );
}

export function WorkoutGroupBar() {
  const { username } = useUser();
  const {
    activeSession,
    pendingInvites,
    createGroupSession,
    joinGroupSession,
    leaveGroupSession,
    phase,
  } = useWorkout();

  const [showInviteModal, setShowInviteModal] = useState(false);
  const [inviteUsername, setInviteUsername] = useState("");
  const [isInviting, setIsInviting] = useState(false);
  const [inviteError, setInviteError] = useState<string | null>(null);
  const [showLeaveConfirm, setShowLeaveConfirm] = useState(false);
  const [selectedMember, setSelectedMember] = useState<GroupSessionMember | null>(null);

  // Filter out current user from member lists
  const otherSessionMembers = activeSession?.members.filter(m => m.userId !== username) ?? [];
  const hasOtherMembers = otherSessionMembers.length > 0;

  // Get next up info (only show if it's not us)
  const nextUp = activeSession?.nextUp;

  // Only show during active workout phases (or if invites pending)
  if (phase === "preview" || phase === "loading" || phase === "complete") {
    if (pendingInvites.length === 0) return null;
  }

  const handleInvite = async () => {
    if (!inviteUsername.trim()) return;

    setIsInviting(true);
    setInviteError(null);

    const result = await createGroupSession(inviteUsername.trim());

    setIsInviting(false);

    if (result.session) {
      setShowInviteModal(false);
      setInviteUsername("");
    } else {
      setInviteError(result.error || "Failed to invite user");
    }
  };

  const handleAcceptInvite = async (inviteId: string) => {
    await joinGroupSession(inviteId);
  };

  const handleDeclineInvite = async (_inviteId: string) => {
    // For now, just remove from local list
  };

  const handleLeaveGroup = async () => {
    await leaveGroupSession();
    setShowLeaveConfirm(false);
  };

  return (
    <div className="w-full space-y-3">
      {/* Next Up banner - show during active workout */}
      {nextUp && activeSession?.status === "active" && username && (
        <NextUpBanner nextUp={nextUp} currentUsername={username} />
      )}

      {/* Pending invites banner */}
      {pendingInvites.length > 0 && (
        <div className="space-y-2">
          {pendingInvites.map((invite) => (
            <Card key={invite.id} className="p-3 bg-primary/10 border-primary/30">
              <div className="flex items-center justify-between gap-4">
                <div className="flex-1">
                  <div className="font-medium text-sm">
                    {invite.fromUser} invited you to workout together
                  </div>
                  {invite.session && (
                    <div className="text-xs text-muted-foreground">
                      {invite.session.members.length} people in group
                    </div>
                  )}
                </div>
                <div className="flex gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleDeclineInvite(invite.id)}
                  >
                    Decline
                  </Button>
                  <Button
                    size="sm"
                    onClick={() => handleAcceptInvite(invite.id)}
                  >
                    Join
                  </Button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* Active group members - only show OTHER members */}
      {hasOtherMembers && (
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Users className="h-4 w-4" />
              <span>Workout Partners</span>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setShowLeaveConfirm(true)}
            >
              <LogOut className="h-4 w-4 mr-1" />
              Leave
            </Button>
          </div>

          <div className="flex gap-2 overflow-x-auto pb-2">
            {otherSessionMembers.map((member) => (
              <SessionMemberCard
                key={member.userId}
                member={member}
                onClick={() => setSelectedMember(member)}
              />
            ))}

            {/* Add person button */}
            <Button
              variant="outline"
              className="min-w-[100px] h-auto py-3"
              onClick={() => setShowInviteModal(true)}
            >
              <UserPlus className="h-4 w-4 mr-2" />
              Add
            </Button>
          </div>
        </div>
      )}

      {/* Show add person button when no group exists during workout */}
      {!hasOtherMembers && !activeSession && phase !== "preview" && phase !== "loading" && phase !== "complete" && (
        <div className="flex justify-center">
          <Button
            variant="outline"
            onClick={() => setShowInviteModal(true)}
          >
            <UserPlus className="h-4 w-4 mr-2" />
            Add Person to Workout
          </Button>
        </div>
      )}

      {/* Invite modal */}
      <Dialog open={showInviteModal} onOpenChange={setShowInviteModal}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Invite to Workout</DialogTitle>
            <DialogDescription>
              Enter a username to invite them to workout with you
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-4">
            <Input
              placeholder="Username"
              value={inviteUsername}
              onChange={(e) => setInviteUsername(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleInvite()}
            />
            {inviteError && (
              <p className="text-sm text-destructive">{inviteError}</p>
            )}
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setShowInviteModal(false)}>
              Cancel
            </Button>
            <Button onClick={handleInvite} disabled={isInviting || !inviteUsername.trim()}>
              {isInviting ? "Inviting..." : "Send Invite"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Leave confirmation dialog */}
      <Dialog open={showLeaveConfirm} onOpenChange={setShowLeaveConfirm}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Leave Group?</DialogTitle>
            <DialogDescription>
              Are you sure you want to leave this workout group? Your workout will continue but you won't see others' progress.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowLeaveConfirm(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleLeaveGroup}>
              Leave Group
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Member workout modal */}
      <MemberWorkoutModal
        member={selectedMember}
        open={selectedMember !== null}
        onClose={() => setSelectedMember(null)}
      />
    </div>
  );
}
