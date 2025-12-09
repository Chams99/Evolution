import 'package:flutter/material.dart';
import 'dart:async';

class TimerPanel extends StatefulWidget {
  final int? timerDurationSeconds;
  final Function(int?) onTimerChanged;
  final Function()? onTimerEnd;
  final bool isSimulationPaused;

  const TimerPanel({
    super.key,
    this.timerDurationSeconds,
    required this.onTimerChanged,
    this.onTimerEnd,
    this.isSimulationPaused = false,
  });

  @override
  State<TimerPanel> createState() => _TimerPanelState();
}

class _TimerPanelState extends State<TimerPanel> {
  int? _selectedDuration;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.timerDurationSeconds;
    _remainingSeconds = widget.timerDurationSeconds ?? 0;
  }

  @override
  void didUpdateWidget(TimerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pause timer if simulation is paused
    if (widget.isSimulationPaused && _isRunning) {
      _stopTimer();
    }
    // Update duration if changed
    if (widget.timerDurationSeconds != oldWidget.timerDurationSeconds) {
      _selectedDuration = widget.timerDurationSeconds;
      if (!_isRunning) {
        _remainingSeconds = widget.timerDurationSeconds ?? 0;
      }
    }
  }

  void _startTimer() {
    if (_selectedDuration == null || _selectedDuration! <= 0) return;
    if (widget.isSimulationPaused) return; // Don't start if simulation is paused

    setState(() {
      _remainingSeconds = _selectedDuration!;
      _isRunning = true;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.isSimulationPaused) {
        // Pause timer if simulation is paused
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _stopTimer();
          widget.onTimerEnd?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _remainingSeconds = _selectedDuration ?? 0;
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Timer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Timer display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isRunning && _remainingSeconds < 10
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.blueAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isRunning && _remainingSeconds < 10
                    ? Colors.red
                    : Colors.blueAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                _isRunning ? _formatTime(_remainingSeconds) : _formatTime(_selectedDuration ?? 0),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _isRunning && _remainingSeconds < 10
                      ? Colors.red
                      : Colors.blueAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Duration selector
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedDuration,
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                  ),
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No Timer')),
                    const DropdownMenuItem(value: 30, child: Text('30 seconds')),
                    const DropdownMenuItem(value: 60, child: Text('1 minute')),
                    const DropdownMenuItem(value: 120, child: Text('2 minutes')),
                    const DropdownMenuItem(value: 300, child: Text('5 minutes')),
                    const DropdownMenuItem(value: 600, child: Text('10 minutes')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDuration = value;
                      _remainingSeconds = value ?? 0;
                    });
                    widget.onTimerChanged(value);
                    if (!_isRunning) {
                      _resetTimer();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isRunning)
                ElevatedButton.icon(
                  onPressed: _selectedDuration != null && _selectedDuration! > 0
                      ? _startTimer
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: _stopTimer,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

