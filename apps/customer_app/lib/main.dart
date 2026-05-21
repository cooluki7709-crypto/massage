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
  List<dynamic> providers = [];
  Map<String, dynamic>? selectedService;
  Map<String, dynamic>? activeBooking;
  bool loading = false;
  String? error;
  String? realtimeMessage;
  Map<String, dynamic>? providerLocation;

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
          providerLocation = Map<String, dynamic>.from(payload);
          realtimeMessage = 'Provider location updated.';
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
        repository.nearbyProviders(),
      ]);
      setState(() {
        providers = results[0];
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

  Future<void> bookSelectedProvider({
    required String providerId,
    required String providerName,
    required Map<String, dynamic> service,
  }) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final booking = await ref.read(customerRepositoryProvider).createBooking(
            service['id'] as String,
            providerId: providerId,
          );
      attachRealtimeListeners();
      setState(() {
        selectedService = service;
        activeBooking = booking;
        realtimeMessage = 'Booking request sent to $providerName. Waiting for provider response.';
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

  Future<void> openProviderDetail(Map<String, dynamic> provider) async {
    final providerId = provider['id'] as String?;
    if (providerId == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return ProviderDetailSheet(
          providerPreview: provider,
          loader: () => ref.read(customerRepositoryProvider).getProviderDetail(providerId),
          onBookService: (service) async {
            Navigator.of(context).pop();
            await bookSelectedProvider(
              providerId: providerId,
              providerName: provider['displayName'] as String? ?? 'Provider',
              service: service,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final booking = activeBooking;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Choose a provider', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            auth == null
                ? 'Sign in to start booking.'
                : 'Browse nearby providers, open one profile, choose one service, and send a direct booking request.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: auth == null
                ? () async {
                    await ref.read(authControllerProvider.notifier).signInDemoCustomer();
                    final pushResult = await ref.read(pushTokenRegistrarProvider).registerCurrentDevice();
                    attachRealtimeListeners();
                    await loadCatalog();
                    if (mounted) {
                      setState(() => realtimeMessage = pushResult.message);
                    }
                  }
                : loadCatalog,
            icon: const Icon(Icons.login),
            label: Text(auth == null ? 'Demo customer login' : 'Refresh providers'),
          ),
          const SizedBox(height: 16),
          if (auth == null)
            const EmptyPanel(text: 'Login loads nearby providers, provider detail, and direct booking actions from the API.')
          else ...[
            FlowStatusBar(
              activeStep: booking == null ? 0 : (booking['chatRoom'] != null ? 3 : 2),
            ),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ErrorPanel(text: error!),
            if (realtimeMessage != null) EmptyPanel(text: realtimeMessage!),
            if (providerLocation != null) ProviderLocationPanel(location: providerLocation!),
            const SizedBox(height: 12),
            if (booking != null) ...[
              DirectBookingStatusPanel(
                activeBooking: booking,
                onRefreshBooking: loading ? null : () => refreshBooking(),
              ),
              const SizedBox(height: 16),
            ],
            Text('Nearby providers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (providers.isEmpty)
              const EmptyPanel(text: 'Nearby verified providers will appear before booking confirmation.')
            else
              for (final provider in providers)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.spa_outlined)),
                    title: Text(provider['displayName'] as String? ?? 'Provider'),
                    subtitle: Text('${provider['distanceMeters'] ?? '?'} m - ${provider['status'] ?? 'UNKNOWN'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openProviderDetail(provider as Map<String, dynamic>),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class ProviderLocationPanel extends StatelessWidget {
  const ProviderLocationPanel({super.key, required this.location});

  final Map<String, dynamic> location;

  @override
  Widget build(BuildContext context) {
    final lat = location['lat'];
    final lng = location['lng'];
    final recordedAt = location['recordedAt'] ?? 'just now';
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.navigation_outlined)),
        title: const Text('Provider on the way'),
        subtitle: Text('Lat $lat, Lng $lng\nUpdated $recordedAt'),
        isThreeLine: true,
      ),
    );
  }
}

class FlowStatusBar extends StatelessWidget {
  const FlowStatusBar({super.key, required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final steps = ['List', 'Detail', 'Request', 'Chat'];
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

class DirectBookingStatusPanel extends StatelessWidget {
  const DirectBookingStatusPanel({
    super.key,
    required this.activeBooking,
    required this.onRefreshBooking,
  });

  final Map<String, dynamic>? activeBooking;
  final VoidCallback? onRefreshBooking;

  @override
  Widget build(BuildContext context) {
    final booking = activeBooking;
    if (booking == null) {
      return const SizedBox.shrink();
    }

    final status = booking['status'] ?? 'OPEN_MATCHING';
    final chatRoom = booking['chatRoom'] as Map<String, dynamic>?;
    final selectedProvider = booking['selectedProvider'] as Map<String, dynamic>?;
    final serviceList = booking['services'] is List<dynamic> ? booking['services'] as List<dynamic> : [];
    final firstService = serviceList.isEmpty ? null : serviceList.first as Map<String, dynamic>;
    final service = firstService?['service'] as Map<String, dynamic>?;
    final statusText = switch (status) {
      'OPEN_MATCHING' => 'Request sent. Waiting for the provider to accept or decline.',
      'MATCHED' => 'Provider accepted. Waiting for service start to unlock chat.',
      'IN_SERVICE' => 'Service started. Chat is available now.',
      'COMPLETED' => 'Service completed.',
      'EXPIRED' => 'The provider declined or the request expired. Choose another provider.',
      _ => 'Current booking status: $status',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Direct booking status', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Booking ${booking['id']}'),
            Text('Status: $status'),
            if (service != null) Text('Service: ${service['name']}'),
            if (selectedProvider != null) Text('Provider: ${selectedProvider['displayName']}'),
            if (chatRoom != null) Text('Chat room ready: ${chatRoom['id']}'),
            const SizedBox(height: 12),
            EmptyPanel(text: statusText),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRefreshBooking,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh booking status'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProviderDetailSheet extends StatelessWidget {
  const ProviderDetailSheet({
    super.key,
    required this.providerPreview,
    required this.loader,
    required this.onBookService,
  });

  final Map<String, dynamic> providerPreview;
  final Future<Map<String, dynamic>> Function() loader;
  final Future<void> Function(Map<String, dynamic> service) onBookService;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: loader(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final detail = snapshot.data ?? providerPreview;
          final reviews = detail['reviews'] is List<dynamic> ? detail['reviews'] as List<dynamic> : [];
          final services = detail['services'] is List<dynamic> ? detail['services'] as List<dynamic> : [];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail['displayName'] as String? ?? 'Provider', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  '${providerPreview['distanceMeters'] ?? '?'} m away • ${detail['bio'] ?? 'Massage provider profile'}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (reviews.isEmpty)
                  const EmptyPanel(text: 'No reviews yet.')
                else
                  for (final review in reviews.take(3))
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.star_outline)),
                        title: Text('Rating ${review['rating'] ?? '-'}'),
                        subtitle: Text(review['comment'] as String? ?? 'No comment'),
                      ),
                    ),
                const SizedBox(height: 16),
                Text('Services', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (services.isEmpty)
                  const EmptyPanel(text: 'No services configured yet.')
                else
                  for (final item in services)
                    Builder(
                      builder: (context) {
                        final providerService = item as Map<String, dynamic>;
                        final service = providerService['service'] as Map<String, dynamic>? ?? <String, dynamic>{};
                        return Card(
                          child: ListTile(
                            title: Text(service['name'] as String? ?? 'Service'),
                            subtitle: Text('${service['durationMin'] ?? '-'} min • ${service['basePrice'] ?? '-'} VND'),
                            trailing: FilledButton(
                              onPressed: () => onBookService(service),
                              child: const Text('Book'),
                            ),
                          ),
                        );
                      },
                    ),
              ],
            ),
          );
        },
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
      title: 'Direct booking',
      subtitle: 'Customer chooses one provider, the provider accepts or rejects, then chat opens on service start.',
      items: ['Customer selects provider', 'Provider accepts request', 'Provider starts service chat'],
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
