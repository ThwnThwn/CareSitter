import 'package:flutter/material.dart';

class CareTimelineTimelineEvent {
  final String time;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDone;

  const CareTimelineTimelineEvent(this.time, this.title, this.description,
      this.icon, this.color, this.isDone);
}
