import 'package:flutter/material.dart';

import '../presentation/design/agent_talk_theme.dart';
import '../presentation/home_screen.dart';

class AgentTalkApp extends StatelessWidget {
  const AgentTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoxHandoff',
      debugShowCheckedModeBanner: false,
      theme: buildAgentTalkDarkTheme(),
      home: const HomeScreen(),
    );
  }
}
