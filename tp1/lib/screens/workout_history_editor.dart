import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/data_service.dart';
import '../services/progression.dart';

class WorkoutHistoryEditor extends StatefulWidget {
  final Workout workout;
  const WorkoutHistoryEditor({super.key, required this.workout});
  @override
  State<WorkoutHistoryEditor> createState() => _WorkoutHistoryEditorState();
}

class _WorkoutHistoryEditorState extends State<WorkoutHistoryEditor> {
  late Workout _draft = widget.workout;
  bool _saving = false;
  String? _error;
  Future<void> _edit(int ei, int si) async {
    final set = _draft.exercises[ei].sets[si];
    String weight = '${set.weight ?? 0}', reps = '${set.reps ?? 0}';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Correct set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: weight,
              onChanged: (v) => weight = v,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextFormField(
              initialValue: reps,
              onChanged: (v) => reps = v,
              decoration: const InputDecoration(labelText: 'Repetitions'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final w = double.tryParse(weight), r = int.tryParse(reps);
    if (w == null ||
        !w.isFinite ||
        w < 0 ||
        w > 1000 ||
        r == null ||
        r < 0 ||
        r > 1000) {
      setState(
        () => _error = 'Enter valid weight and repetitions from 0 to 1000.',
      );
      return;
    }
    final sets = [..._draft.exercises[ei].sets];
    sets[si] = set.copyWith(weight: w, reps: r);
    final exercises = [..._draft.exercises];
    exercises[ei] = exercises[ei].copyWith(sets: sets);
    setState(() {
      _draft = _draft.copyWith(exercises: exercises);
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DataService.instance.correctWorkout(_draft);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to save. Check the workout date and set values, then retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review workout')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          initialValue: _draft.name,
          decoration: const InputDecoration(labelText: 'Workout name'),
          onChanged: (v) => _draft = _draft.copyWith(name: v),
        ),
        TextButton.icon(
          icon: const Icon(Icons.calendar_month),
          label: Text(
            '${_draft.date.year}-${_draft.date.month}-${_draft.date.day}',
          ),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _draft.date.isAfter(DateTime.now())
                  ? DateTime.now()
                  : _draft.date,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null && mounted) {
              setState(() => _draft = _draft.copyWith(date: date));
            }
          },
        ),
        TextFormField(
          initialValue: _draft.notes,
          decoration: const InputDecoration(labelText: 'Session notes'),
          onChanged: (v) => _draft = _draft.copyWith(notes: v),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ..._draft.exercises.asMap().entries.map((entry) {
          final target = ProgressionTarget.next(entry.value);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.value.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...entry.value.sets.asMap().entries.map(
                    (s) => ListTile(
                      title: Text(
                        'Set ${s.key + 1}: ${s.value.weight ?? 0} kg x ${s.value.reps ?? 0}',
                      ),
                      subtitle: Text(
                        s.value.isWarmup
                            ? 'Warm-up'
                            : s.value.isCompleted
                            ? 'Completed'
                            : 'Incomplete',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(entry.key, s.key),
                    ),
                  ),
                  if (target != null) ...[
                    Text(
                      'Next target (8-12 reps): ${target.weight} kg x ${target.reps}',
                    ),
                    Text(
                      target.reason,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save corrections'),
        ),
      ],
    ),
  );
}
