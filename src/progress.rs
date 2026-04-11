use schlift::workout::v1::{CompletedSet, ProposedSet};

pub fn compute_next_up_set(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> Option<ProposedSet> {
    // Find first proposed set that doesn't have a matching completed set
    proposed_sets
        .iter()
        .find(|p| {
            !completed_sets
                .iter()
                .any(|c| c.proposed_set_id == p.id && c.ended_at > 0)
        })
        .cloned()
}
