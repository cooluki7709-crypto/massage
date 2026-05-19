import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app_state.dart';

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
      ProviderMvpScreen(title: 'Chat', items: ['Customer chat', 'Support']),
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
  List<dynamic> openBookings = [];
  Set<String> joinedBookingIds = {};
  bool isOnline = false;
  bool loading = false;
  String? statusMessage;
  String? error;

  Future<void> signInAndLoad() async {
    setState(() {
      loading = true;
      error = null;
      statusMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signInDemoProvider();
      await goOnline();
      await loadOpenBookings();
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

  Future<void> loadOpenBookings() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final bookings = await ref.read(providerRepositoryProvider).openBookings();
      setState(() => openBookings = bookings);
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
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
            onPressed: auth == null ? signInAndLoad : loadOpenBookings,
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
            RequestFlowBar(
              activeStep: !isOnline ? 0 : (openBookings.isEmpty ? 1 : (joinedBookingIds.isEmpty ? 2 : 3)),
            ),
            const SizedBox(height: 16),
            if (openBookings.isEmpty)
              const InfoCard(text: 'No open matching jobs yet. Create a booking in the Customer app, then refresh.')
            else
              for (final booking in openBookings)
                OpenBookingCard(
                  booking: booking as Map<String, dynamic>,
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
    required this.joined,
    required this.loading,
    required this.onJoin,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> booking;
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Booking ${booking['id']}'),
            Text('Scheduled: ${booking['scheduledStartAt'] ?? 'soon'}'),
            Text('Payment opens as authorization, customer selects final provider.'),
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
