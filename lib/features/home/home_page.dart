import 'package:flutter/material.dart';

import '../feed/feed_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeedPage(showCreatePrompt: false, showNotificationBell: true);
  }
}
