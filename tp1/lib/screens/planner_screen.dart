import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/data_service.dart';
import '../services/training_plan_store.dart';
import 'workouts_screen.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  TrainingPlanStore? _store;
  DateTime _date = DateTime.now();
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = DataService.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Sign in to plan training.');
      return;
    }
    try {
      final store = TrainingPlanStore(user.id);
      await store.load();
      if (mounted) setState(() => _store = store);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to load your plan. Please reopen this page.',
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _store!.save();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Workout?> _choose() => showModalBottomSheet<Workout>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          children: [
            const ListTile(title: Text('Choose a saved routine')),
            ...DataService.instance.workoutTemplates.map(
              (w) => ListTile(
                title: Text(w.name),
                subtitle: Text('${w.exercises.length} exercises'),
                trailing: const Icon(Icons.add),
                onTap: () => Navigator.pop(context, w),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> _assign({int? weekday, bool rotation = false}) async {
    final workout = await _choose();
    if (workout == null || !mounted) return;
    setState(() {
      if (rotation) {
        _store!.rotation.add(workout);
      } else if (weekday != null) {
        _store!.weekly[weekday] = workout;
      } else {
        _store!.overrides[TrainingPlanStore.dayKey(_date)] = workout;
      }
    });
    await _save();
  }

  Future<void> _start(Workout routine) async {
    final data = DataService.instance;
    if (data.activeWorkoutDraft != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish your active workout before starting another.'),
        ),
      );
      return;
    }
    await data.startRoutine(routine, date: _date);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const WorkoutsScreen()),
    );
  }

  Future<void> _weighIn() async {
    String input = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Body weight (kg)'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => input = value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight in kilograms'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    final kg = double.tryParse(value.replaceAll(',', '.'));
    if (kg == null || !kg.isFinite || kg <= 0 || kg > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid weight from 0 to 1000 kg.'),
        ),
      );
      return;
    }
    setState(() => _store!.recordWeight(_date, kg));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final routine = store?.forDate(_date);
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weights = store?.weighIns.entries.toList() ?? [];
    weights.sort((a, b) => b.key.compareTo(a.key));
    return Scaffold(
      appBar: AppBar(title: const Text('Training Planner')),
      body: _error != null
          ? Center(child: Text(_error!))
          : store == null
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  Text(
                    'Build your training week',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(TrainingPlanStore.dayKey(_date)),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null && mounted) setState(() => _date = date);
                    },
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine?.name ?? 'Rest day',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (routine != null)
                                FilledButton.icon(
                                  onPressed: () => _start(routine),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Start session'),
                                ),
                              OutlinedButton(
                                onPressed: () => _assign(),
                                child: const Text('Change this date'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  setState(
                                    () =>
                                        store.overrides[TrainingPlanStore.dayKey(
                                              _date,
                                            )] =
                                            null,
                                  );
                                  await _save();
                                },
                                child: const Text('Rest this date'),
                              ),
                              if (store.overrides.containsKey(
                                TrainingPlanStore.dayKey(_date),
                              ))
                                TextButton(
                                  onPressed: () async {
                                    setState(
                                      () => store.overrides.remove(
                                        TrainingPlanStore.dayKey(_date),
                                      ),
                                    );
                                    await _save();
                                  },
                                  child: const Text('Use regular plan'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Rotating routines'),
                    subtitle: const Text(
                      'Choose the next routine regardless of weekday',
                    ),
                    value: store.useRotation,
                    onChanged: (value) async {
                      setState(() => store.useRotation = value);
                      await _save();
                    },
                  ),
                  if (store.useRotation) ...[
                    ...store.rotation.asMap().entries.map(
                      (e) => ListTile(
                        leading: Icon(
                          e.key == store.rotationIndex % store.rotation.length
                              ? Icons.play_circle
                              : Icons.fitness_center,
                        ),
                        title: Text(e.value.name),
                        trailing: IconButton(
                          tooltip: 'Remove routine',
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            setState(() => store.rotation.removeAt(e.key));
                            await _save();
                          },
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _assign(rotation: true),
                      child: const Text('Add rotation routine'),
                    ),
                    TextButton(
                      onPressed: store.rotation.isEmpty
                          ? null
                          : () async {
                              setState(() => store.rotationIndex++);
                              await _save();
                            },
                      child: const Text('Advance to next routine'),
                    ),
                  ] else
                    ...List.generate(
                      7,
                      (i) => Card(
                        child: ListTile(
                          title: Text(days[i]),
                          subtitle: Text(
                            store.weekly[i + 1]?.name ?? 'Rest day',
                          ),
                          onTap: () => _assign(weekday: i + 1),
                          trailing: IconButton(
                            tooltip: 'Clear day',
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              setState(() => store.weekly.remove(i + 1));
                              await _save();
                            },
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Body weight',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  OutlinedButton.icon(
                    onPressed: _weighIn,
                    icon: const Icon(Icons.monitor_weight_outlined),
                    label: const Text('Record weight for selected date'),
                  ),
                  if (weights.isEmpty)
                    const Text('Your measurements will appear here.'),
                  ...weights.map(
                    (entry) => ListTile(
                      title: Text('${entry.value.toStringAsFixed(1)} kg'),
                      subtitle: Text(entry.key),
                      trailing: IconButton(
                        tooltip: 'Delete measurement',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          setState(() => store.weighIns.remove(entry.key));
                          await _save();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
