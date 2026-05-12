import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/socket_service.dart';
import '../services/notification_service.dart';

class NotificationButton extends StatefulWidget {
  const NotificationButton({super.key});

  @override
  State<NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<NotificationButton> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.addListener(_onNotificationChanged);
  }

  void _onNotificationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    NotificationService.instance.removeListener(_onNotificationChanged);
    super.dispose();
  }

  List<Map<String, dynamic>> get _notifications => NotificationService.instance.notifications;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Color(0xFF4D8EFF)),
          onPressed: _showNotificationsSheet,
        ),
        if (_notifications.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Text(
                _notifications.length > 9 ? '9+' : '${_notifications.length}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: const Color(0xFF191B23),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: const Color(0xFF2A2D35)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NOTIFICATIONS',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        NotificationService.instance.clearNotifications();
                        Navigator.pop(ctx);
                      },
                      child: const Text('CLEAR'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2D35)),
              Expanded(
                child: _notifications.isEmpty
                    ? Center(
                        child: Text(
                          'No notifications yet',
                          style: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final title = notification['title']?.toString() ?? 'Notification';
                          final message = notification['message']?.toString() ?? notification['body']?.toString() ?? '';
                          final type = notification['type']?.toString() ?? 'general';
                          final combinedText = '$title $message $type'.toLowerCase();
                          final isDelete = combinedText.contains('removed') || 
                                           combinedText.contains('cancelled') ||
                                           combinedText.contains('deleted') ||
                                           combinedText.contains('unassigned');

                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              final t = type.toLowerCase();
                              if (t.contains('incident') || t.contains('report') || t.contains('assignment')) {
                                Navigator.pushReplacementNamed(
                                  context, 
                                  '/reports',
                                  arguments: {'incidentId': notification['incidentId']},
                                );
                              } else if (t.contains('resource')) {
                                Navigator.pushReplacementNamed(context, '/resources');
                              } else if (t.contains('alert')) {
                                Navigator.pushReplacementNamed(context, '/alerts');
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDelete ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF10131A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDelete ? Colors.red.withValues(alpha: 0.3) : const Color(0xFF2A2D35)),
                              ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isDelete ? Colors.red.withValues(alpha: 0.15) : Colors.blueAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isDelete ? Icons.delete_outline : Icons.notifications_active,
                                    color: isDelete ? Colors.redAccent : Colors.blueAccent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (message.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          message,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF9CA3AF),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        type.toUpperCase(),
                                        style: GoogleFonts.spaceGrotesk(
                                          color: Colors.blueAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}