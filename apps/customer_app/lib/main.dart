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
      title: 'HANDS Customer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E8E4A)),
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
      const BookingsScreen(),
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
  List<dynamic> providers = [];
  Map<String, dynamic>? activeBooking;
  bool loading = false;
  String? error;
  String? notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authControllerProvider);
      if (auth != null) {
        unawaited(loadHome());
      }
    });
  }

  Future<void> loadHome() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repository = ref.read(customerRepositoryProvider);
      final results = await Future.wait([
        repository.nearbyProviders(),
        repository.listBookings(),
      ]);
      final bookings = results[1];
      final booking = latestActiveBooking(bookings);
      if (booking != null) {
        repository.joinBookingRoom(booking['id'] as String);
      }
      setState(() {
        providers = results[0];
        activeBooking = booking;
      });
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> signInAndLoad() async {
    setState(() {
      loading = true;
      error = null;
      notice = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signInDemoCustomer();
      final pushResult = await ref.read(pushTokenRegistrarProvider).registerCurrentDevice();
      await loadHome();
      if (mounted) {
        setState(() => notice = pushResult.message);
      }
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

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ProviderDetailPage(
          providerPreview: provider,
          loader: () => ref.read(customerRepositoryProvider).getProviderDetail(providerId),
          onBookService: (detail, service) async {
            final navigator = Navigator.of(context);
            final booked = await navigator.push<Map<String, dynamic>>(
              MaterialPageRoute(
                builder: (context) => BookingConfirmationPage(
                  providerDetail: detail,
                  selectedService: service,
                  onConfirm: () => ref.read(customerRepositoryProvider).createBooking(
                        service['id'] as String,
                        providerId: detail['id'] as String,
                      ),
                ),
              ),
            );

            if (!mounted || booked == null) {
              return;
            }

            setState(() {
              activeBooking = booked;
              notice = 'Booking created. Waiting for provider response.';
            });

            await navigator.push<void>(
              MaterialPageRoute(
                builder: (context) => BookingWaitingPage(
                  initialBooking: booked,
                  onBookingUpdated: (booking) => setState(() => activeBooking = booking),
                ),
              ),
            );
            await loadHome();
          },
        ),
      ),
    );
  }

  Future<void> openActiveBooking() async {
    final booking = activeBooking;
    if (booking == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingWaitingPage(
          initialBooking: booking,
          onBookingUpdated: (updated) => setState(() => activeBooking = updated),
        ),
      ),
    );
    await loadHome();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_back_outlined),
              const SizedBox(width: 10),
              Text('Ho Chi Minh City', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              const Icon(Icons.favorite_border),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: auth == null ? signInAndLoad : loadHome,
                  icon: const Icon(Icons.search),
                  label: Text(auth == null ? 'Demo customer login' : 'Refresh providers'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(text: error!),
          ],
          if (notice != null) ...[
            const SizedBox(height: 12),
            InfoBanner(text: notice!),
          ],
          if (auth == null) ...[
            const SizedBox(height: 12),
            const EmptyPanel(text: 'Login to load the nearby therapist list, provider detail pages, and booking flow.'),
          ] else ...[
            if (activeBooking != null) ...[
              const SizedBox(height: 12),
              ActiveBookingBanner(
                booking: activeBooking!,
                onOpen: openActiveBooking,
              ),
            ],
            const SizedBox(height: 16),
            const FilterChipRow(),
            const SizedBox(height: 16),
            if (providers.isEmpty)
              const EmptyPanel(text: 'Nearby providers will appear here after refresh.')
            else
              for (final item in providers)
                ProviderListCard(
                  provider: item,
                  onTap: () => openProviderDetail(item),
                ),
          ],
        ],
      ),
    );
  }
}

class ProviderListCard extends StatelessWidget {
  const ProviderListCard({
    super.key,
    required this.provider,
    required this.onTap,
  });

  final Map<String, dynamic> provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = provider['displayName'] as String? ?? 'Provider';
    final distanceMeters = provider['distanceMeters'] as num?;
    final rating = providerAverageRating(provider);
    final reviewCount = providerReviewCount(provider);
    final availableLabel = provider['status'] == 'ONLINE_AVAILABLE' ? 'Available now' : 'Available soon';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ProviderThumbnail(name: displayName, size: 108),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          availableLabel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 22, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        Text('($reviewCount reviews)'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 20, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(formatDistance(distanceMeters)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5E8E4A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reserve'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterChipRow extends StatelessWidget {
  const FilterChipRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        OutlineChip(label: 'Filters', icon: Icons.tune),
        OutlineChip(label: 'Near me'),
        OutlineChip(label: 'Top booked'),
        OutlineChip(label: 'Service type', icon: Icons.keyboard_arrow_down),
      ],
    );
  }
}

class OutlineChip extends StatelessWidget {
  const OutlineChip({
    super.key,
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 6),
          ],
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class ActiveBookingBanner extends StatelessWidget {
  const ActiveBookingBanner({
    super.key,
    required this.booking,
    required this.onOpen,
  });

  final Map<String, dynamic> booking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final service = firstBookingService(booking);
    final provider = booking['selectedProvider'] as Map<String, dynamic>?;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        title: Text(service?['name'] as String? ?? 'Active booking'),
        subtitle: Text(provider == null ? 'Waiting for provider response' : 'Provider: ${provider['displayName']}'),
        trailing: FilledButton.tonal(
          onPressed: onOpen,
          child: const Text('Open'),
        ),
      ),
    );
  }
}

class ProviderDetailPage extends StatelessWidget {
  const ProviderDetailPage({
    super.key,
    required this.providerPreview,
    required this.loader,
    required this.onBookService,
  });

  final Map<String, dynamic> providerPreview;
  final Future<Map<String, dynamic>> Function() loader;
  final Future<void> Function(Map<String, dynamic> detail, Map<String, dynamic> service) onBookService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: loader(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final detail = snapshot.data ?? providerPreview;
          final reviews = detail['reviews'] is List<dynamic> ? detail['reviews'] as List<dynamic> : [];
          final services = detail['services'] is List<dynamic> ? detail['services'] as List<dynamic> : [];
          final displayName = detail['displayName'] as String? ?? 'Provider';
          final rating = providerAverageRating(detail);
          final reviewCount = providerReviewCount(detail);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                leading: const BackButton(color: Colors.black),
                backgroundColor: Colors.white,
                actions: const [
                  CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Icon(Icons.favorite_border, color: Colors.black)),
                  SizedBox(width: 8),
                  CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Icon(Icons.share_outlined, color: Colors.black)),
                  SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFFF2EBD9)),
                      Center(child: ProviderThumbnail(name: displayName, size: 180)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 22, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(formatDistance(providerPreview['distanceMeters'] as num?)),
                          const SizedBox(width: 14),
                          const Icon(Icons.star_rounded, size: 22, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text('${rating.toStringAsFixed(1)} ($reviewCount reviews)'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF8AA773)),
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0xFFF9FCF6),
                        ),
                        child: const Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.verified_user_outlined, color: Color(0xFF5E8E4A)),
                                SizedBox(width: 10),
                                Expanded(child: Text('No tip, no travel fee')),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.shield_outlined, color: Color(0xFF5E8E4A)),
                                SizedBox(width: 10),
                                Expanded(child: Text('Protected when the assigned therapist changes')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        (detail['bio'] as String?) ?? 'Experienced therapist profile ready for booking.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      Text('Services', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      for (final item in services)
                        Builder(
                          builder: (context) {
                            final providerService = item as Map<String, dynamic>;
                            final service = providerService['service'] as Map<String, dynamic>? ?? <String, dynamic>{};
                            return ServiceCard(
                              service: service,
                              onBook: () => onBookService(detail, service),
                            );
                          },
                        ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Text('Reviews', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          TextButton(onPressed: () {}, child: const Text('View all')),
                        ],
                      ),
                      ReviewSummaryCard(
                        rating: rating,
                        reviewCount: reviewCount,
                      ),
                      const SizedBox(height: 12),
                      if (reviews.isEmpty)
                        const EmptyPanel(text: 'No reviews yet.')
                      else
                        for (final review in reviews.take(3))
                          ReviewCard(review: review as Map<String, dynamic>),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.service,
    required this.onBook,
  });

  final Map<String, dynamic> service;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final duration = service['durationMin'];
    final price = service['basePrice'];
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service['name'] as String? ?? 'Service', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DurationPill(label: '${duration ?? '-'} min'),
                const DurationPill(label: '90 min'),
                const DurationPill(label: '120 min'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  '${formatCurrency(price)} VND',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5E8E4A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reserve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DurationPill extends StatelessWidget {
  const DurationPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class ReviewSummaryCard extends StatelessWidget {
  const ReviewSummaryCard({
    super.key,
    required this.rating,
    required this.reviewCount,
  });

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rating.toStringAsFixed(1)} / 5',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text('★★★★★', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 20)),
                  const SizedBox(height: 4),
                  Text('($reviewCount reviews)'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: List.generate(
                  5,
                  (index) {
                    final stars = 5 - index;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text('$stars'),
                          const SizedBox(width: 8),
                          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: stars == 5 ? 1 : 0,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 12),
                Text('Customer', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(review['createdAt']?.toString().split('T').first ?? ''),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < ((review['rating'] as num?)?.toInt() ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(review['comment'] as String? ?? 'No comment'),
          ],
        ),
      ),
    );
  }
}

class BookingConfirmationPage extends ConsumerStatefulWidget {
  const BookingConfirmationPage({
    super.key,
    required this.providerDetail,
    required this.selectedService,
    required this.onConfirm,
  });

  final Map<String, dynamic> providerDetail;
  final Map<String, dynamic> selectedService;
  final Future<Map<String, dynamic>> Function() onConfirm;

  @override
  ConsumerState<BookingConfirmationPage> createState() => _BookingConfirmationPageState();
}

class _BookingConfirmationPageState extends ConsumerState<BookingConfirmationPage> {
  final nameController = TextEditingController(text: 'Demo Customer');
  final phoneController = TextEditingController(text: '0865907184');
  final addressController = TextEditingController(text: 'Royal Villa Da Lat, Ward 7, Da Lat, Lam Dong');
  final couponController = TextEditingController();
  bool submitting = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    couponController.dispose();
    super.dispose();
  }

  Future<void> confirmBooking() async {
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final booking = await widget.onConfirm();
      if (mounted) {
        Navigator.of(context).pop(booking);
      }
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.selectedService;
    final provider = widget.providerDetail;
    return Scaffold(
      appBar: AppBar(title: const Text('Booking information')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            BookingSectionCard(
              title: 'My address',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                  TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            BookingSectionCard(
              title: service['name'] as String? ?? 'Selected service',
              child: Row(
                children: [
                  ProviderThumbnail(name: provider['displayName'] as String? ?? 'Provider', size: 72),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${service['durationMin'] ?? '-'} min | ${formatCurrency(service['basePrice'])} VND'),
                        const SizedBox(height: 10),
                        Text(provider['displayName'] as String? ?? 'Provider', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text('${providerAverageRating(provider).toStringAsFixed(1)} (${providerReviewCount(provider)} reviews)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            BookingSectionCard(
              title: 'Payment method',
              child: Row(
                children: [
                  const Expanded(child: Text('Cash payment')),
                  FilledButton.tonal(onPressed: () {}, child: const Text('View all')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            BookingSectionCard(
              title: 'Discount code',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: couponController,
                      decoration: const InputDecoration(hintText: 'Enter coupon code'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(onPressed: () {}, child: const Text('Apply')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            BookingSectionCard(
              title: 'Payment summary',
              child: Row(
                children: [
                  const Expanded(child: Text('Total')),
                  Text(
                    '${formatCurrency(service['basePrice'])} VND',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              ErrorPanel(text: error!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: submitting ? null : confirmBooking,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5E8E4A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          child: Text(submitting ? 'Creating booking...' : 'Book now'),
        ),
      ),
    );
  }
}

class BookingSectionCard extends StatelessWidget {
  const BookingSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class BookingWaitingPage extends ConsumerStatefulWidget {
  const BookingWaitingPage({
    super.key,
    required this.initialBooking,
    required this.onBookingUpdated,
  });

  final Map<String, dynamic> initialBooking;
  final ValueChanged<Map<String, dynamic>> onBookingUpdated;

  @override
  ConsumerState<BookingWaitingPage> createState() => _BookingWaitingPageState();
}

class _BookingWaitingPageState extends ConsumerState<BookingWaitingPage> {
  Timer? timer;
  Map<String, dynamic>? booking;
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    booking = widget.initialBooking;
    final bookingId = booking?['id'] as String?;
    if (bookingId != null) {
      ref.read(customerRepositoryProvider).joinBookingRoom(bookingId);
    }
    timer = Timer.periodic(const Duration(seconds: 5), (_) => refreshBooking(showLoading: false));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refreshBooking({bool showLoading = true}) async {
    final bookingId = booking?['id'] as String?;
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
      final updated = await ref.read(customerRepositoryProvider).getBooking(bookingId);
      if (!mounted) {
        return;
      }
      setState(() => booking = updated);
      widget.onBookingUpdated(updated);
    } catch (exception) {
      if (mounted) {
        setState(() => error = '$exception');
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> cancelBooking() async {
    final bookingId = booking?['id'] as String?;
    if (bookingId == null) {
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final updated = await ref.read(customerRepositoryProvider).cancelBooking(bookingId);
      if (!mounted) {
        return;
      }
      widget.onBookingUpdated(updated);
      Navigator.of(context).pop();
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> selectProvider(Map<String, dynamic> participant) async {
    final bookingId = booking?['id'] as String?;
    final providerId = participant['providerProfileId'] as String?;
    if (bookingId == null || providerId == null) {
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final updated = await ref.read(customerRepositoryProvider).selectProvider(bookingId, providerId);
      if (!mounted) {
        return;
      }
      setState(() => booking = updated);
      widget.onBookingUpdated(updated);
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
    final currentBooking = booking;
    final participants = currentBooking?['participants'] is List<dynamic>
        ? currentBooking!['participants'] as List<dynamic>
        : <dynamic>[];
    final selectedProvider = currentBooking?['selectedProvider'] as Map<String, dynamic>?;
    final service = currentBooking == null ? null : firstBookingService(currentBooking);
    final status = currentBooking?['status'] as String? ?? 'OPEN_MATCHING';
    final waitingText = status == 'OPEN_MATCHING'
        ? (selectedProvider == null
            ? 'Waiting for ${providerDisplayName(currentBooking)} to respond...'
            : 'Waiting for the selected therapist to start the service...')
        : status == 'MATCHED'
            ? 'Provider accepted. Waiting for service start...'
            : status == 'IN_SERVICE'
                ? 'Service started. Continue in Chat.'
                : 'Status: $status';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  const MapPlaceholder(),
                  Positioned(
                    top: 18,
                    left: 18,
                    child: const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: BackButton(),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    right: 18,
                    child: FilledButton(
                      onPressed: loading ? null : cancelBooking,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE84B4B),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel request'),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            providerDisplayName(currentBooking),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(waitingText, style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Request auto-expires at ${formatExpiry(currentBooking?['expiresAt'] as String?)}'),
                          const SizedBox(height: 16),
                          if (loading) const LinearProgressIndicator(),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            ErrorPanel(text: error!),
                          ],
                          const SizedBox(height: 12),
                          if (service != null)
                            Text(
                              '${service['name']} • ${service['durationMin']} min • ${formatCurrency(service['basePrice'])} VND',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: bookingProgress(status),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 18),
                          if (selectedProvider == null && participants.length > 1) ...[
                            Text('Available therapists', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            for (final item in participants)
                              TherapistSelectionCard(
                                participant: item,
                                onSelect: () => selectProvider(item),
                              ),
                          ] else if (selectedProvider != null) ...[
                            Text('Selected therapist', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            TherapistDisplayCard(provider: selectedProvider),
                          ] else ...[
                            const EmptyPanel(text: 'Waiting for a provider response. Other available therapists can appear here later.'),
                          ],
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: loading ? null : () => refreshBooking(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh status'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TherapistSelectionCard extends StatelessWidget {
  const TherapistSelectionCard({
    super.key,
    required this.participant,
    required this.onSelect,
  });

  final Map<String, dynamic> participant;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final provider = participant['providerProfile'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ProviderThumbnail(name: provider['displayName'] as String? ?? 'Provider', size: 84),
        title: Text(provider['displayName'] as String? ?? 'Provider'),
        subtitle: Text('${participant['status'] ?? 'JOINED'} • ${formatDistance(provider['distanceMeters'] as num?)}'),
        trailing: FilledButton(
          onPressed: onSelect,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5E8E4A),
            foregroundColor: Colors.white,
          ),
          child: const Text('Select'),
        ),
      ),
    );
  }
}

class TherapistDisplayCard extends StatelessWidget {
  const TherapistDisplayCard({
    super.key,
    required this.provider,
  });

  final Map<String, dynamic> provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ProviderThumbnail(name: provider['displayName'] as String? ?? 'Provider', size: 84),
        title: Text(provider['displayName'] as String? ?? 'Provider'),
        subtitle: const Text('Ready for confirmation / service delivery'),
      ),
    );
  }
}

class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD6F2DD),
            Color(0xFFEFE8D5),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: MapPainter()),
          ),
          Align(
            alignment: const Alignment(0, -0.1),
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFF5E8E4A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.25, -0.05),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF5E8E4A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFB8B8B8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final thinPaint = Paint()
      ..color = const Color(0xFFD6D6D6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final mainRoad = Path()
      ..moveTo(size.width * 0.1, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.55, size.width * 0.5, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.68, size.height * 0.15, size.width * 0.9, size.height * 0.2);
    canvas.drawPath(mainRoad, roadPaint);

    final branch = Path()
      ..moveTo(size.width * 0.42, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.32, size.height * 0.45, size.width * 0.24, size.height * 0.28);
    canvas.drawPath(branch, thinPaint);

    final branchTwo = Path()
      ..moveTo(size.width * 0.55, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.64, size.height * 0.55, size.width * 0.78, size.height * 0.72);
    canvas.drawPath(branchTwo, thinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProviderThumbnail extends StatelessWidget {
  const ProviderThumbnail({
    super.key,
    required this.name,
    required this.size,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty
        ? 'P'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((word) => word.characters.first.toUpperCase())
            .join();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFE8E1D3),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF5E8E4A),
          ),
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
      title: 'Providers',
      subtitle: 'Full provider list sorted by distance.',
      enabled: auth != null,
      disabledText: 'Login first to load nearby providers.',
      loader: () => ref.read(customerRepositoryProvider).nearbyProviders(),
      labelBuilder: (provider) {
        final item = provider as Map<String, dynamic>;
        return '${item['displayName'] ?? 'Provider'} • ${formatDistance(item['distanceMeters'] as num?)}';
      },
    );
  }
}

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return MvpAsyncList(
      title: 'Bookings',
      subtitle: 'Recent customer bookings and waiting requests.',
      enabled: auth != null,
      disabledText: 'Login first to load customer bookings.',
      loader: () => ref.read(customerRepositoryProvider).listBookings(),
      labelBuilder: (booking) {
        final item = booking as Map<String, dynamic>;
        final service = firstBookingService(item);
        return '${service?['name'] ?? 'Booking'} • ${item['status']}';
      },
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
      setState(() => statusMessage = 'No service chat yet. The provider has to start the service first.');
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
            auth == null ? 'Login to load the latest booking chat.' : 'Realtime messages with your assigned therapist.',
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
            const EmptyPanel(text: 'Chat appears after the provider starts the service flow.')
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

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
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

Map<String, dynamic>? latestActiveBooking(List<dynamic> bookings) {
  const activeStatuses = {
    'OPEN_MATCHING',
    'MATCHED',
    'PROVIDER_ON_THE_WAY',
    'ARRIVED',
    'IN_SERVICE',
  };
  final items = bookings
      .whereType<Map<String, dynamic>>()
      .where((booking) => activeStatuses.contains(booking['status']))
      .toList()
    ..sort((left, right) {
      final leftValue = (left['openedAt'] ?? left['createdAt'] ?? '') as String;
      final rightValue = (right['openedAt'] ?? right['createdAt'] ?? '') as String;
      return rightValue.compareTo(leftValue);
    });
  return items.isEmpty ? null : items.first;
}

Map<String, dynamic>? firstBookingService(Map<String, dynamic> booking) {
  final services = booking['services'] is List<dynamic> ? booking['services'] as List<dynamic> : [];
  if (services.isEmpty) {
    return null;
  }
  final first = services.first as Map<String, dynamic>;
  final service = first['service'];
  return service is Map<String, dynamic> ? service : null;
}

String providerDisplayName(Map<String, dynamic>? booking) {
  if (booking == null) {
    return 'Booking';
  }
  final provider = booking['selectedProvider'] as Map<String, dynamic>?;
  if (provider != null) {
    return provider['displayName'] as String? ?? 'Selected provider';
  }
  final participants = booking['participants'] is List<dynamic> ? booking['participants'] as List<dynamic> : [];
  if (participants.isNotEmpty) {
    final first = participants.first as Map<String, dynamic>;
    final providerProfile = first['providerProfile'] as Map<String, dynamic>?;
    if (providerProfile != null) {
      return providerProfile['displayName'] as String? ?? 'Provider';
    }
  }
  return 'Booking request';
}

double providerAverageRating(Map<String, dynamic> provider) {
  final reviews = provider['reviews'] is List<dynamic> ? provider['reviews'] as List<dynamic> : [];
  if (reviews.isEmpty) {
    return 5;
  }
  final total = reviews.fold<double>(0, (sum, item) {
    final rating = (item as Map<String, dynamic>)['rating'] as num? ?? 0;
    return sum + rating.toDouble();
  });
  return total / reviews.length;
}

int providerReviewCount(Map<String, dynamic> provider) {
  final reviews = provider['reviews'];
  if (reviews is List<dynamic>) {
    return reviews.length;
  }
  return 0;
}

String formatDistance(num? meters) {
  if (meters == null) {
    return '?';
  }
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}

String formatCurrency(dynamic amount) {
  final number = (amount as num?)?.toInt() ?? 0;
  final text = number.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    final reverseIndex = text.length - index;
    buffer.write(text[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}

double bookingProgress(String status) {
  switch (status) {
    case 'OPEN_MATCHING':
      return 0.15;
    case 'MATCHED':
      return 0.5;
    case 'PROVIDER_ON_THE_WAY':
      return 0.7;
    case 'ARRIVED':
      return 0.82;
    case 'IN_SERVICE':
      return 1;
    default:
      return 0.08;
  }
}

String formatExpiry(String? isoValue) {
  if (isoValue == null) {
    return '--:--';
  }
  final date = DateTime.tryParse(isoValue)?.toLocal();
  if (date == null) {
    return '--:--';
  }
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
