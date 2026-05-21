import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app_state.dart';
import 'src/core/realtime_socket.dart';

void main() {
  runApp(const ProviderScope(child: ProviderApp()));
}

class ProviderApp extends StatelessWidget {
  const ProviderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Provider',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const ProviderShell(),
    );
  }
}

class ProviderShell extends ConsumerStatefulWidget {
  const ProviderShell({super.key});

  @override
  ConsumerState<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends ConsumerState<ProviderShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      RequestsScreen(),
      ProviderMvpScreen(title: 'Schedule', items: ['Availability', 'Available soon', 'Busy until']),
      EarningsScreen(),
      ChatScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar_outlined), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.verified_user_outlined), label: 'Profile'),
        ],
      ),
    );
  }
}

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  late final RealtimeSocket _socket;
  List<dynamic> openBookings = [];
  Set<String> joinedBookingIds = {};
  bool isOnline = false;
  bool loading = false;
  String? statusMessage;
  String? error;

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

    _socket.onEvent('booking.opened', (payload) {
      if (!mounted) {
        return;
      }
      setState(() => statusMessage = 'New open matching job received.');
      unawaited(loadOpenBookings(showLoading: false));
    });

    _socket.onEvent('booking.matched', (payload) {
      if (!mounted) {
        return;
      }
      setState(() => statusMessage = 'Booking matched. Check selected provider state.');
      unawaited(loadOpenBookings(showLoading: false));
    });

    _socket.onEvent('booking.expired', (payload) {
      if (!mounted) {
        return;
      }
      setState(() => statusMessage = 'A matching job expired.');
      unawaited(loadOpenBookings(showLoading: false));
    });
  }

  void detachRealtimeListeners() {
    for (final event in ['booking.opened', 'booking.matched', 'booking.expired']) {
      _socket.offEvent(event);
    }
  }

  Future<void> signInAndLoad() async {
    setState(() {
      loading = true;
      error = null;
      statusMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signInDemoProvider();
      final pushResult = await ref.read(pushTokenRegistrarProvider).registerCurrentDevice();
      attachRealtimeListeners();
      await goOnline();
      await loadOpenBookings();
      if (mounted) {
        setState(() => statusMessage = pushResult.message);
      }
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> goOnline() async {
    await ref.read(providerRepositoryProvider).goOnline();
    setState(() {
      isOnline = true;
      statusMessage = 'Online and location shared.';
    });
  }

  Future<void> loadOpenBookings({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final bookings = await ref.read(providerRepositoryProvider).openBookings();
      bookings.sort((left, right) {
        final leftMap = left as Map<String, dynamic>;
        final rightMap = right as Map<String, dynamic>;
        final leftValue = (leftMap['openedAt'] ?? leftMap['createdAt'] ?? '') as String;
        final rightValue = (rightMap['openedAt'] ?? rightMap['createdAt'] ?? '') as String;
        return rightValue.compareTo(leftValue);
      });
      setState(() => openBookings = bookings);
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted && showLoading) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> joinBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['id'] as String;
    setState(() {
      loading = true;
      error = null;
      statusMessage = null;
    });
    try {
      await ref.read(providerRepositoryProvider).joinBooking(bookingId);
      setState(() {
        joinedBookingIds = {...joinedBookingIds, bookingId};
        statusMessage = 'Joined booking. Waiting for customer selection.';
      });
      await loadOpenBookings();
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> respondToBooking(Map<String, dynamic> booking, bool accepted) async {
    final bookingId = booking['id'] as String;
    setState(() {
      loading = true;
      error = null;
      statusMessage = null;
    });
    try {
      if (accepted) {
        await ref.read(providerRepositoryProvider).acceptBooking(bookingId);
      } else {
        await ref.read(providerRepositoryProvider).rejectBooking(bookingId);
        joinedBookingIds = joinedBookingIds.where((id) => id != bookingId).toSet();
      }
      setState(() => statusMessage = accepted ? 'Accepted participation.' : 'Rejected participation.');
      await loadOpenBookings();
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
    final hasJoinedRequest = joinedBookingIds.isNotEmpty;
    final hasSelection = openBookings.any((booking) => booking is Map<String, dynamic> && booking['status'] == 'MATCHED');
    final activeStep = !isOnline
        ? 0
        : openBookings.isEmpty
            ? 1
            : hasSelection
                ? 3
                : hasJoinedRequest
                    ? 2
                    : 1;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Open booking requests', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            auth == null ? 'Login to receive matching jobs.' : 'Join open bookings and wait for customer selection.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: auth == null ? signInAndLoad : () => loadOpenBookings(),
            icon: const Icon(Icons.login),
            label: Text(auth == null ? 'Demo provider login' : 'Refresh open jobs'),
          ),
          const SizedBox(height: 12),
          ProviderStatusPanel(
            isSignedIn: auth != null,
            isOnline: isOnline,
            loading: loading,
            onGoOnline: auth == null
                ? null
                : () async {
                    setState(() {
                      loading = true;
                      error = null;
                    });
                    try {
                      await goOnline();
                      await loadOpenBookings();
                    } catch (exception) {
                      setState(() => error = '$exception');
                    } finally {
                      if (mounted) {
                        setState(() => loading = false);
                      }
                    }
                  },
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (statusMessage != null) ...[
            const SizedBox(height: 12),
            InfoCard(text: statusMessage!),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorCard(text: error!),
          ],
          const SizedBox(height: 20),
          if (auth == null)
            const InfoCard(text: 'Login first to load open bookings from the API.')
          else ...[
            RequestFlowBar(activeStep: activeStep),
            const SizedBox(height: 16),
            if (openBookings.isEmpty)
              const InfoCard(text: 'No open matching jobs yet. Create a booking in the Customer app, then refresh.')
            else
              for (final booking in openBookings)
                OpenBookingCard(
                  booking: booking as Map<String, dynamic>,
                  isNewest: identical(booking, openBookings.first),
                  joined: joinedBookingIds.contains(booking['id']),
                  loading: loading,
                  onJoin: () => joinBooking(booking),
                  onAccept: () => respondToBooking(booking, true),
                  onReject: () => respondToBooking(booking, false),
                ),
          ],
        ],
      ),
    );
  }
}

class ProviderStatusPanel extends StatelessWidget {
  const ProviderStatusPanel({
    super.key,
    required this.isSignedIn,
    required this.isOnline,
    required this.loading,
    required this.onGoOnline,
  });

  final bool isSignedIn;
  final bool isOnline;
  final bool loading;
  final VoidCallback? onGoOnline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isOnline
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(isOnline ? Icons.radar_outlined : Icons.power_settings_new),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isOnline ? 'Online available' : 'Offline', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    isOnline ? 'Location is shared for matching.' : 'Go online to receive open matching jobs.',
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: !isSignedIn || loading || isOnline ? null : onGoOnline,
              child: const Text('Go online'),
            ),
          ],
        ),
      ),
    );
  }
}

class RequestFlowBar extends StatelessWidget {
  const RequestFlowBar({super.key, required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final steps = ['Online', 'Listen', 'Join', 'Selected'];
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
                  child: Text(steps[index], textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class OpenBookingCard extends StatelessWidget {
  const OpenBookingCard({
    super.key,
    required this.booking,
    required this.isNewest,
    required this.joined,
    required this.loading,
    required this.onJoin,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> booking;
  final bool isNewest;
  final bool joined;
  final bool loading;
  final VoidCallback onJoin;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final services = booking['services'] is List<dynamic> ? booking['services'] as List<dynamic> : [];
    final firstService = services.isNotEmpty ? services.first as Map<String, dynamic> : <String, dynamic>{};
    final service = firstService['service'] as Map<String, dynamic>?;
    final participants = booking['participants'] is List<dynamic> ? booking['participants'] as List<dynamic> : [];
    final selectedProvider = booking['selectedProvider'] as Map<String, dynamic>?;
    final isMatched = booking['status'] == 'MATCHED';
    final nextStep = !joined
        ? 'Join this job to enter the customer shortlist.'
        : isMatched
            ? 'Customer already selected a provider. Review the final state.'
            : 'You are in the shortlist. Wait for the customer to pick one provider.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.spa_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service?['name'] as String? ?? 'Massage booking', style: Theme.of(context).textTheme.titleLarge),
                      Text('${booking['status']} - ${participants.length} provider(s) joined'),
                      Text('Code ${shortBookingCode(booking['id'] as String?)}'),
                    ],
                  ),
                ),
                if (isNewest)
                  Chip(
                    label: const Text('Latest'),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Booking ${booking['id']}'),
            Text('Scheduled: ${booking['scheduledStartAt'] ?? 'soon'}'),
            Text('Payment opens as authorization, customer selects final provider.'),
            const SizedBox(height: 8),
            InfoCard(text: nextStep),
            const SizedBox(height: 8),
            BookingOpsRow(
              items: [
                ProviderSummaryItem(label: 'Joined now', value: '${participants.length} provider(s)'),
                ProviderSummaryItem(
                  label: 'Final provider',
                  value: selectedProvider?['displayName'] as String? ?? (isMatched ? 'Assigned' : 'Waiting'),
                ),
              ],
            ),
            if (selectedProvider != null) ...[
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.assignment_turned_in_outlined)),
                  title: Text(selectedProvider['displayName'] as String? ?? 'Selected provider'),
                  subtitle: Text(isMatched ? 'Booking is matched and moving into service delivery.' : 'Customer selection pending.'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!joined)
              FilledButton.icon(
                onPressed: loading ? null : onJoin,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Join open matching'),
              )
            else ...[
              const InfoCard(text: 'Joined. The customer can now select you as final provider.'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: loading ? null : onReject,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: loading ? null : onAccept,
                      icon: const Icon(Icons.check),
                      label: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BookingOpsRow extends StatelessWidget {
  const BookingOpsRow({super.key, required this.items});

  final List<ProviderSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < items.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[index].label, style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(items[index].value, style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ProviderSummaryItem {
  const ProviderSummaryItem({required this.label, required this.value});

  final String label;
  final String value;
}

String shortBookingCode(String? id) {
  if (id == null || id.isEmpty) {
    return '----';
  }
  return id.length <= 8 ? id : id.substring(0, 8).toUpperCase();
}

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Earnings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            auth == null ? 'Login to view completed service earnings.' : 'Track gross, tips, fees, and net payout.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (auth == null)
            const InfoCard(text: 'Demo provider login is available on the Requests tab.')
          else
            FutureBuilder<List<dynamic>>(
              future: ref.read(providerRepositoryProvider).earnings(),
              builder: (context, earningsSnapshot) {
                return FutureBuilder<Map<String, dynamic>>(
                  future: ref.read(providerRepositoryProvider).earningsSummary(),
                  builder: (context, summarySnapshot) {
                    if (earningsSnapshot.connectionState == ConnectionState.waiting ||
                        summarySnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final summary = summarySnapshot.data ?? <String, dynamic>{};
                    final earnings = earningsSnapshot.data ?? [];
                    final currency = summary['currency'] ?? 'VND';

                    return FutureBuilder<List<dynamic>>(
                      future: ref.read(providerRepositoryProvider).payoutBatches(),
                      builder: (context, payoutSnapshot) {
                        final batches = payoutSnapshot.data ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Net payout', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${summary['netAmount'] ?? 0} $currency',
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Tips ${summary['tipAmount'] ?? 0} $currency'),
                                    Text('Platform fee ${summary['platformFee'] ?? 0} $currency'),
                                    Text('Payout batches ${batches.length}'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (earnings.isEmpty)
                              const InfoCard(text: 'Completed jobs will appear here.')
                            else
                              for (final earning in earnings)
                                Card(
                                  child: ListTile(
                                    title: Text('${earning['netAmount']} ${earning['currency'] ?? currency}'),
                                    subtitle: Text('Booking ${earning['bookingId']} - ${earning['status']}'),
                                    trailing: Text('+${earning['tipAmount'] ?? 0} tip'),
                                  ),
                                ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
        ],
      ),
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
  String? bookingId;
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
        statusMessage = 'New customer message received.';
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
        await ref.read(authControllerProvider.notifier).signInDemoProvider();
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
    final bookings = await ref.read(providerRepositoryProvider).listBookings();
    final booking = bookings.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['chatRoom'] != null,
          orElse: () => null,
        );
    final room = booking?['chatRoom'] as Map<String, dynamic>?;
    if (room == null) {
      setState(() => statusMessage = 'No selected booking chat yet.');
      return;
    }

    final roomId = room['id'] as String;
    ref.read(providerRepositoryProvider).joinChat(roomId);
    final loadedMessages = await ref.read(providerRepositoryProvider).listChatMessages(roomId);
    setState(() {
      chatRoomId = roomId;
      bookingId = booking?['id'] as String?;
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
    ref.read(providerRepositoryProvider).sendChatMessage(roomId, text);
  }

  Future<void> shareLocation() async {
    final activeBookingId = bookingId;
    if (activeBookingId == null) {
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref.read(providerRepositoryProvider).updateLocation(bookingId: activeBookingId);
      setState(() => statusMessage = 'Current location shared with the customer.');
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Chat', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            auth == null ? 'Login to load selected booking chats.' : 'Realtime messages with the customer.',
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
            InfoCard(text: statusMessage!),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorCard(text: error!),
          ],
          const SizedBox(height: 16),
          if (chatRoomId == null)
            const InfoCard(text: 'A chat room appears when the customer selects you.')
          else ...[
            Text('Room $chatRoomId', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: loading ? null : shareLocation,
              icon: const Icon(Icons.my_location_outlined),
              label: const Text('Share current location'),
            ),
            const SizedBox(height: 8),
            if (messages.isEmpty)
              const InfoCard(text: 'No messages yet.')
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            auth == null ? 'Not signed in' : 'Signed in as ${auth.user['phone']}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (auth == null)
            const InfoCard(text: 'Login first to manage verification.')
          else
            FutureBuilder<Map<String, dynamic>>(
              future: ref.read(providerRepositoryProvider).verification(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final verification = snapshot.data ?? <String, dynamic>{};
                final files = verification['files'] is List<dynamic> ? verification['files'] as List<dynamic> : [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: ListTile(
                        title: Text('Verification ${verification['status'] ?? 'DRAFT'}'),
                        subtitle: Text(
                          verification['rejectionReason'] == null
                              ? '${files.length} file(s) attached'
                              : '${verification['rejectionReason']}',
                        ),
                        trailing: const Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final upload = await ref.read(providerRepositoryProvider).createVerificationUpload();
                        final file = upload['file'] as Map<String, dynamic>?;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Upload contract created for ${file?['key'] ?? 'file'}')),
                          );
                        }
                      },
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Create verification upload'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        await ref.read(providerRepositoryProvider).submitVerification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Verification submitted')),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Submit for review'),
                    ),
                    const SizedBox(height: 12),
                    for (final item in ['Massage menu', 'Pricing', 'Online toggle'])
                      Card(
                        child: ListTile(
                          title: Text(item),
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

class ProviderMvpScreen extends StatelessWidget {
  const ProviderMvpScreen({super.key, required this.title, this.subtitle, required this.items});

  final String title;
  final String? subtitle;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 16),
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

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.text});

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

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.text});

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
