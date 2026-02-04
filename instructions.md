this is a workout tracking app that enables collaborative workouts. it should be very simple.

- common schema using buf and proto between frontend/backend
- grpc server using go
- frontend stream subscriptions should be inflappable stream. reconnect at all costs etc
- all information about each user is stored in a single sqlite file for that user
- frontend written in react using shadcn and tailwind
- when a user signs up they pick a name and they have a uuid assigned to them, and their sqlite file created



in user db:

user {
    id: uuid
    name: string
    created_at: timestamp
}

workout {
    id: uuid
    start_time: timestamp
    end_time: timestamp
}

proposed_set {
    id: uuid
    workout_id: uuid
    workout_order: int
    exercise: enum
    target_reps: int
    target_weight: float
    warmup: bool
}

completed_set {
    id: uuid
    workout_id: uuid
    proposed_set_id: uuid
    actual_reps: int
    actual_weight: float
    started_at: timestamp
    ended_at: timestamp
    rest_until: timestamp
}

in group db:

group_workout {
    id: uuid
    started_at: timestamp
    ended_at: timestamp
}

group_workout_participant {
    user_id: uuid
    group_workout_id: uuid
    workout_id: uuid
    joined_at: timestamp
    left_at: timestamp
}


rpcs:

for monitoring group workout:
rpc InviteUser(InviteRequest) returns (InviteResponse);
rpc ListenToInvites(InviteListenRequest) returns (stream InviteEvent);
rpc GroupWorkoutProposals(GroupProposalsRequest) returns (stream GroupProposalsResponse);
rpc ConnectToWorkout(ConnectRequest) returns (stream WorkoutEvent);

for your own workout:
rpc StartWorkout(StartWorkoutRequest) returns (StartWorkoutResponse);
rpc ModifyProposedSet(ModifyProposedSetRequest) returns (ModifyProposedSetResponse);
rpc StartProposedSet(StartProposedSetRequest) returns (StartProposedSetResponse);
rpc CompleteProposedSet(CompleteProposedSetRequest) returns (CompleteProposedSetResponse);
rpc EndWorkout(EndWorkoutRequest) returns (EndWorkoutResponse);

frontend

baseurl/workout/uuid - a workout that's started by user with uuid
baseurl/friends - list of friends and their current workout status (todo later)
baseurl/history - list of past workouts 


solo workout:
user can start a workout, see proposed sets and their order, start/complete/reorder them, see a ledger of their completed sets, end workout
the times should all update in realtime locally based off the timestamps stored in sqlite sent via the api
whether or not a workout is in a group can be checked by seeing if there's a group_workout_participant entry for the user's current workout

group workout:
the app is always connected to the listen to invites stream. when an invite is received, user can click to join the workout. they then start listening to the groupworkoutproposals and a modal comes up. this should send and receive the ideal exercise types each user wants to do. the user ticks all the workouts they want to do, and they can see what the other participants have selected live through updates over the stream. once everyone is ready, whatever each user selected gets sent by their client to their current workout as an updated proposed set list (if there's no workout started yet one gets started for them too). then users are streamed updates about other users current completed sets and proposed sets. each client should be able to derive who would go next given the state of proposed rests and completed sets of others and themselves. there should be an indication of who's up next at the top of the screen, plus your own workout, reusing the solo workout components for that.
the first time a user subscribes to the group workout proposals stream (ie a page reload), the server should send the full state of all participants' proposed and completed sets for the current workout, so the client can fully populate its state.
