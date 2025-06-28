import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/notification.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<NotificationsProvider>(
          builder: (context, notifications, child) {
        if (notifications.pendingNotifications.isEmpty) {
          return SizedBox(
              height: 96,
              child: Center(
                  child: Text(
                AppLocalizations.of(context)!.noPendingNotifications,
                style: TextStyle(
                    fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize),
              )));
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 48.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.pendingNotifications,
                    style: Theme.of(context).textTheme.headlineSmall),
                Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.pendingNotifications.length,
                  itemBuilder: (context, index) {
                    final notification =
                        notifications.pendingNotifications[index];
                    final notificationTime = notification.payload != null &&
                            notification.payload!.isNotEmpty
                        ? ViaNotificationPayload.fromString(
                                notification.payload!)
                            .scheduledTime
                            .toLocal()
                        : null;
                    return Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: ListTile(
                        leading: Icon(Icons.notifications),
                        title: Text(notification.title ?? "No Title"),
                        subtitle: notificationTime != null
                            ? Text(AppLocalizations.of(context)!.scheduledFor(
                                DateFormat.Hm().format(notificationTime)))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await notifications
                                .cancelNotification(notification.id);
                            if (notifications.pendingNotifications.isEmpty &&
                                context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (notifications.pendingNotifications.length > 2)
                  FilledButton(
                      onPressed: () => {
                            notifications.cancelAllNotifications(),
                            Navigator.of(context).pop()
                          },
                      child: Text(AppLocalizations.of(context)!
                          .cancelAllNotifications)),
              ],
            ),
          );
        }
      }),
    );
  }
}
