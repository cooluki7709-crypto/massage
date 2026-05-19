import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app_state.dart';
import 'src/core/realtime_socket.dart';

void main() {
  runApp(const ProviderScope(child: CustomerApp()));
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Massage VN',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const CustomerShell(),
    );
  }
}

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const ProvidersScreen(),
      const MatchingScreen(),
      const ChatScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.spa_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Providers'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final RealtimeSocket _socket;
  List<dynamic> services = [];
  List<dynamic> providers = [];
  Map<String, dynamic>? selectedService;
  Map<String, dynamic>? activeBooking;
  bool loading = false;
  String? error;
  String? realtimeMessage;
  String? providerLocationMessage;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(realtimeSocketProvider);
  }

  @override
  void dispose() {
    detachRealtimeListeners();
    super.dispose();
  }

  void attachRealtimeListeners() {
    detachRealtimeListeners();

    _socket.onEvent('provider.joined', (payload) {
      if (!mounted) {
        return;
      }
      setState(() => realtimeMessage = 'Provider joined. Refreshing matching list.');
      unawaited(refreshBooking(showLoading: false));
    });

    _socket.onEvent('booking.matched', (payload) {
      if (!mounted) {
        return;
      }
      setState(() => realtimeMessage = 'Provider selected. Chat and trip tracking are ready.');
      unawaited(refreshBooking(showLoading: false));
    });

    _socket.onEvent('booking.expired', (payload) {
      if (!mounted) {
        return;
      }
      setState(() => realtimeMessage = 'Booking expired before final selection.');
      unawaited(refreshBooking(showLoading: false));
    });

    _socket.onEvent('provider.location.updated', (payload) {
      if (!mounted) {
        return;
      }
      if (payload is Map) {
        setState(() {
          providerLocationMessage = 'Provider location: ${payload['lat']}, ${payload['lng']}';
        });
      }
    });
  }

  void detachRealtimeListeners() {
    for (final event in [
      'provider.joined',
      'booking.matched',
      'booking.expired',
      'provider.location.updated',
    ]) {
      _socket.offEvent(event);
    }
  }

  Future<void> loadCatalog() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repository = ref.read(customerRepositoryProvider);
      final results = await Future.wait([
        repository.listServices(),
        repository.nearbyProviders(),
      ]);
      setState(() {
        services = results[0];
        providers = results[1];
      });
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> openBooking() async {
    final service = selectedService;
    if (service == null) {
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });
    try {
      final booking = await ref.read(customerRepositoryProvider).createBooking(service['id'] as String);
      attachRealtimeListeners();
      setState(() {
        activeBooking = booking;
        realtimeMessage = 'Matching opened. Listening for providers in realtime.';
      });
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> refreshBooking({bool showLoading = true}) async {
    final bookingId = activeBooking?['id'] as String?;
    if (bookingId == null) {
      return;
    }

    if (showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final booking = await ref.read(customerRepositoryProvider).getBooking(bookingId);
      setState(() => activeBooking = booking);
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted && showLoading) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> selectProvider(Map<String, dynamic> participant) async {
    final bookingId = activeBooking?['id'] as String?;
    final providerId = participant['providerProfileId'] as String?;
    if (bookingId == null || providerId == null) {
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ref.read(customerRepositoryProvider).selectProvider(bookingId, providerId);
      setState(() {
        activeBooking = result;
        realtimeMessage = 'Final provider selected. Matching moved to active booking.';
      });
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final booking = activeBooking;
    final participants = booking?['participants'] is List<dynamic> ? booking!['participants'] as List<dynamic> : [];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Choose a service', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            auth == null ? 'Sign in to start booking.' : 'Service, provider preview, matching, and final selection.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: auth == null
                ? () async {
                    await ref.read(authControllerProvider.notifier).signInDemoCustomer();
                    attachRealtimeListeners();
                    await loadCatalog();
                  }
                : loadCatalog,
            icon: const Icon(Icons.login),
            label: Text(auth == null ? 'Demo customer login' : 'Refresh services'),
          ),
          const SizedBox(height: 16),
          if (auth == null)
            const EmptyPanel(text: 'Login loads service catalog, nearby providers, and booking actions from the API.')
          else ...[
            FlowStatusBar(
              activeStep: booking == null ? (selectedService == null ? 0 : 1) : (participants.isEmpty ? 2 : 3),
            ),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ErrorPanel(text: error!),
            if (realtimeMessage != null) EmptyPanel(text: realtimeMessage!),
            if (providerLocationMessage != null) EmptyPanel(text: providerLocationMessage!),
            const SizedBox(height: 12),
            Text('Services', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (services.isEmpty)
              const EmptyPanel(text: 'Tap refresh services to load the API catalog.')
            else
              for (final service in services)
                Card(
                  child: ListTile(
                    selected: selectedService?['id'] == service['id'],
                    title: Text(service['name'] as String? ?? 'Service'),
                    subtitle: Text('${service['durationMin']} min - ${service['basePrice']} VND'),
                    trailing: selectedService?['id'] == service['id']
                        ? const Icon(Icons.check_circle)
                        : const Icon(Icons.chevron_right),
                    onTap: booking == null ? () => setState(() => selectedService = service as Map<String, dynamic>) : null,
                  ),
                ),
            const SizedBox(height: 16),
            Text('Nearby providers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (providers.isEmpty)
              const EmptyPanel(text: 'Nearby verified providers will appear before booking confirmation.')
            else
              for (final provider in providers.take(3))
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.spa_outlined)),
                    title: Text(provider['displayName'] as String? ?? 'Provider'),
                    subtitle: Text('${provider['distanceMeters'] ?? '?'} m - ${provider['status'] ?? 'UNKNOWN'}'),
                  ),
                ),
            const SizedBox(height: 16),
            BookingActionPanel(
              selectedService: selectedService,
              activeBooking: booking,
              participants: participants,
              onOpenBooking: loading ? null : openBooking,
              onRefreshBooking: loading ? null : () => refreshBooking(),
              onSelectProvider: loading ? null : selectProvider,
            ),
          ],
        ],
      ),
    );
  }
}

class FlowStatusBar extends StatelessWidget {
  const FlowStatusBar({super.key, required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final steps = ['Service', 'Confirm', 'Matching', 'Select'];
    return Row(
      children: [
        for (var index = 0; index < steps.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: index <= activeStep
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    steps[index],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class BookingActionPanel extends StatelessWidget {
  const BookingActionPanel({
    super.key,
    required this.selectedService,
    required this.activeBooking,
    required this.participants,
    required this.onOpenBooking,
    required this.onRefreshBooking,
    required this.onSelectProvider,
  });

  final Map<String, dynamic>? selectedService;
  final Map<String, dynamic>? activeBooking;
  final List<dynamic> participants;
  final VoidCallback? onOpenBooking;
  final VoidCallback? onRefreshBooking;
  final void Function(Map<String, dynamic> participant)? onSelectProvider;

  @override
  Widget build(BuildContext context) {
    final booking = activeBooking;
    if (booking == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Confirm booking', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                selectedService == null
                    ? 'Pick one service to open a realtime matching job.'
                    : '${selectedService!['name']} will open as a cash booking in District 1.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: selectedService == null ? null : onOpenBooking,
                icon: const Icon(Icons.radar_outlined),
                label: const Text('Open realtime matching'),
              ),
            ],
          ),
        ),
      );
    }

    final status = booking['status'] ?? 'OPEN_MATCHING';
    final chatRoom = booking['chatRoom'] as Map<String, dynamic>?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Matching status', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Booking ${booking['id']}'),
            Text('Status: $status'),
            if (chatRoom != null) Text('Chat room ready: ${chatRoom['id']}'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRefreshBooking,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh joined providers'),
            ),
            const SizedBox(height: 12),
            if (participants.isEmpty)
              const EmptyPanel(text: 'Waiting for providers to join. Open the Provider app and join this booking.')
            else
              for (final item in participants)
                ProviderParticipantTile(
                  participant: item as Map<String, dynamic>,
                  onSelect: status == 'OPEN_MATCHING' && onSelectProvider != null
                      ? () => onSelectProvider!(item)
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}

class ProviderParticipantTile extends StatelessWidget {
  const ProviderParticipantTile({super.key, required this.participant, required this.onSelect});

  final Map<String, dynamic> participant;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final provider = participant['providerProfile'] as Map<String, dynamic>?;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_pin_circle_outlined)),
        title: Text(provider?['displayName'] as String? ?? 'Joined provider'),
        subtitle: Text('${participant['status'] ?? 'JOINED'}'),
        trailing: FilledButton(
          onPressed: onSelect,
          child: const Text('Select'),
        ),
      ),
    );
  }
}

class ProvidersScreen extends ConsumerWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return MvpAsyncList(
      title: 'Nearby providers',
      subtitle: 'Sorted by distance and availability.',
      enabled: auth != null,
      disabledText: 'Login first to load nearby verified providers.',
      loader: () => ref.read(customerRepositoryProvider).nearbyProviders(),
      labelBuilder: (provider) {
        return '${provider['displayName'] ?? 'Provider'} - ${provider['distanceMeters'] ?? '?'} m - ${provider['status']}';
      },
    );
  }
}

class MatchingScreen extends StatelessWidget {
  const MatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MvpScreen(
      title: 'Open matching',
      subtitle: 'Bookings emit booking.opened, provider.joined, booking.matched, and booking.expired.',
      items: ['Customer creates booking', 'Providers join realtime', 'Customer selects final provider'],
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final RealtimeSocket _socket;
  final messageController = TextEditingController();
  List<dynamic> messages = [];
  String? chatRoomId;
  String? statusMessage;
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(realtimeSocketProvider);
  }

  @override
  void dispose() {
    _socket.offEvent('chat.message.created');
    messageController.dispose();
    super.dispose();
  }

  void attachChatListener() {
    _socket.offEvent('chat.message.created');
    _socket.onEvent('chat.message.created', (payload) {
      if (!mounted || payload is! Map || payload['chatRoomId'] != chatRoomId) {
        return;
      }
      setState(() {
        messages = [...messages, payload];
        statusMessage = 'New message received.';
      });
    });
  }

  Future<void> signInAndLoadChat() async {
    setState(() {
      loading = true;
      error = null;
      statusMessage = null;
    });
    try {
      if (ref.read(authControllerProvider) == null) {
        await ref.read(authControllerProvider.notifier).signInDemoCustomer();
      }
      await loadLatestChat();
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> loadLatestChat() async {
    final bookings = await ref.read(customerRepositoryProvider).listBookings();
    final booking = bookings.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['chatRoom'] != null,
          orElse: () => null,
        );
    final room = booking?['chatRoom'] as Map<String, dynamic>?;
    if (room == null) {
      setState(() => statusMessage = 'No matched booking chat yet. Select a provider first.');
      return;
    }

    final roomId = room['id'] as String;
    ref.read(customerRepositoryProvider).joinChat(roomId);
    final loadedMessages = await ref.read(customerRepositoryProvider).listChatMessages(roomId);
    setState(() {
      chatRoomId = roomId;
      messages = loadedMessages;
      statusMessage = 'Chat room loaded for booking ${booking?['id']}.';
    });
    attachChatListener();
  }

  Future<void> sendMessage() async {
    final roomId = chatRoomId;
    final text = messageController.text.trim();
    if (roomId == null || text.isEmpty) {
      return;
    }
    messageController.clear();
    ref.read(customerRepositoryProvider).sendChatMessage(roomId, text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Chat', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            auth == null ? 'Login to load the latest matched booking chat.' : 'Realtime customer-provider messages.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: loading ? null : signInAndLoadChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(chatRoomId == null ? 'Load latest chat' : 'Refresh chat'),
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (statusMessage != null) ...[
            const SizedBox(height: 12),
            EmptyPanel(text: statusMessage!),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(text: error!),
          ],
          const SizedBox(height: 16),
          if (chatRoomId == null)
            const EmptyPanel(text: 'A chat room appears after final provider selection.')
          else ...[
            Text('Room $chatRoomId', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (messages.isEmpty)
              const EmptyPanel(text: 'No messages yet.')
            else
              for (final message in messages)
                MessageTile(message: message as Map<String, dynamic>),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Message',
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: sendMessage,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send'),
            ),
          ],
        ],
      ),
    );
  }
}

class MessageTile extends StatelessWidget {
  const MessageTile({super.key, required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final sender = message['sender'] as Map<String, dynamic>?;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(message['body'] as String? ?? ''),
        subtitle: Text(sender?['fullName'] as String? ?? 'Sender'),
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return MvpScreen(
      title: 'Profile',
      subtitle: auth == null ? 'Not signed in' : 'Signed in as ${auth.user['phone']}',
      items: const ['Saved addresses', 'Wallet', 'Reviews', 'Support'],
    );
  }
}

class MvpAsyncList extends StatelessWidget {
  const MvpAsyncList({
    super.key,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.disabledText,
    required this.loader,
    required this.labelBuilder,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final String disabledText;
  final Future<List<dynamic>> Function() loader;
  final String Function(dynamic item) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          if (!enabled)
            EmptyPanel(text: disabledText)
          else
            FutureBuilder<List<dynamic>>(
              future: loader(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const EmptyPanel(text: 'No records yet.');
                }
                return Column(
                  children: [
                    for (final item in items)
                      Card(
                        child: ListTile(
                          title: Text(labelBuilder(item)),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class MvpScreen extends StatelessWidget {
  const MvpScreen({super.key, required this.title, required this.subtitle, required this.items});

  final String title;
  final String subtitle;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          for (final item in items)
            Card(
              child: ListTile(
                title: Text(item),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
      ),
    );
  }
}
