// SPDX-License-Identifier: GPL-2.0
// Helper functions for the undo-commands

#include "command_private.h"
#include "core/divelist.h"
#include "core/display.h" // for amount_selected
#include "core/subsurface-qt/DiveListNotifier.h"

namespace Command {

// Set the current dive either from a list of selected dives,
// or a newly selected dive. In both cases, try to select the
// dive that is newer that is newer than the given date.
// This mimics the old behavior when the current dive changed.
static void setClosestCurrentDive(timestamp_t when, const std::vector<dive *> &selection)
{
	// Start from back until we get the first dive that is before
	// the supposed-to-be selected dive. (Note: this mimics the
	// old behavior when the current dive changed).
	for (auto it = selection.rbegin(); it < selection.rend(); ++it) {
		if ((*it)->when > when && !(*it)->hidden_by_filter) {
			current_dive = *it;
			return;
		}
	}

	// We didn't find a more recent selected dive -> try to
	// find *any* visible selected dive.
	for (dive *d: selection) {
		if (!d->hidden_by_filter) {
			current_dive = d;
			return;
		}
	}

	// No selected dive is visible! Take the closest dive. Note, this might
	// return null, but that just means unsetting the current dive (as no
	// dive is visible anyway).
	current_dive = find_next_visible_dive(when);
}

// Reset the selection to the dives of the "selection" vector and send the appropriate signals.
// Set the current dive to "currentDive". "currentDive" must be an element of "selection" (or
// null if "seletion" is empty). Return true if the selection or current dive changed.
bool setSelection(const std::vector<dive *> &selection, dive *currentDive)
{
	// To do so, generate vectors of dives to be selected and deselected.
	// We send signals batched by trip, so keep track of trip/dive pairs.
	std::vector<std::pair<dive_trip *, dive *>> divesToSelect;
	std::vector<std::pair<dive_trip *, dive *>> divesToDeselect;

	// TODO: We might want to keep track of selected dives in a more efficient way!
	int i;
	dive *d;
	amount_selected = 0; // We recalculate amount_selected
	for_each_dive(i, d) {
		// We only modify dives that are currently visible.
		if (d->hidden_by_filter) {
			d->selected = false; // Note, not necessary, just to be sure
					     // that we get amount_selected right
			continue;
		}

		// Search the dive in the list of selected dives.
		// TODO: By sorting the list in the same way as the backend, this could be made more efficient.
		bool newState = std::find(selection.begin(), selection.end(), d) != selection.end();

		// TODO: Instead of using select_dive() and deselect_dive(), we set selected directly.
		// The reason is that deselect() automatically sets a new current dive, which we
		// don't want, as we set it later anyway.
		// There is other parts of the C++ code that touches the innards directly, but
		// ultimately this should be pushed down to C.
		if (newState && !d->selected) {
			d->selected = true;
			++amount_selected;
			divesToSelect.push_back({ d->divetrip, d });
		} else if (!newState && d->selected) {
			d->selected = false;
			divesToDeselect.push_back({ d->divetrip, d });
		}
	}

	// Send the select and deselect signals
	processByTrip(divesToSelect, [&](dive_trip *trip, const QVector<dive *> &divesInTrip) {
		emit diveListNotifier.divesSelected(trip, divesInTrip);
	});
	processByTrip(divesToDeselect, [&](dive_trip *trip, const QVector<dive *> &divesInTrip) {
		emit diveListNotifier.divesDeselected(trip, divesInTrip);
	});

	bool currentDiveChanged = false;
	if (!currentDive) {
		// If currentDive is null, we have no current dive. In such a case always
		// notify the frontend.
		currentDiveChanged = true;
		emit diveListNotifier.currentDiveChanged();
	} else if (current_dive != currentDive) {
		currentDiveChanged = true;

		// We cannot simply change the currentd dive to the given dive.
		// It might be hidden by a filter and thus not be selected.
		if (currentDive->selected)
			// Current dive is visible and selected. Excellent.
			current_dive = currentDive;
		else
			// Current not visible -> find a different dive.
			setClosestCurrentDive(currentDive->when, selection);
		emit diveListNotifier.currentDiveChanged();
	}

	// return true if selection of current dive changed
	return !divesToSelect.empty() || !divesToDeselect.empty() || currentDiveChanged;
}

// Turn current selection into a vector.
// TODO: This could be made much more efficient if we kept a sorted list of selected dives!
std::vector<dive *> getDiveSelection()
{
	std::vector<dive *> res;
	res.reserve(amount_selected);

	int i;
	dive *d;
	for_each_dive(i, d) {
		if (d->selected)
			res.push_back(d);
	}
	return res;
}

} // namespace Command
