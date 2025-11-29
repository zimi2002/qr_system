import 'package:flutter/material.dart';
import 'package:qr_web_view/services/realtime_stats_service.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final RealtimeStatsService _statsService = RealtimeStatsService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;
  bool _isSubscribed = false;
  String? _selectedGroup; // Selected group label (null = show all)
  bool _hasAppliedFilter = false; // Track if user has applied a filter

  // Color palette: Primary (Blue), Secondary (Purple), Accent (Teal), White
  static const Color _primaryColor = Color(0xFF3B82F6); // Blue
  static const Color _secondaryColor = Color(0xFF8B5CF6); // Purple
  static const Color _accentColor = Color(0xFF06B6D4); // Teal
  static const Color _white = Colors.white;

  // Responsive breakpoint
  static const double _mobileBreakpoint = 768.0;

  /// Helper method to determine if current screen is mobile
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < _mobileBreakpoint;
  }

  /// Maps a grade code to a group label
  /// Examples:
  /// - "6 New" → "6 2026"
  /// - "11 New" → "JEE 2026"
  /// - "11B1" → "JEE"
  /// - "6C1" → "6"
  /// - "7S3" → "7"
  static String classGroupFromGrade(String grade) {
    grade = grade.trim();

    // 1) Handle "<class> New" cases (6 New, 7 New, 10 New, 11 New, etc.)
    final newMatch = RegExp(
      r'^(\d{1,2})\s*New$',
      caseSensitive: false,
    ).firstMatch(grade);
    if (newMatch != null) {
      final cls = newMatch.group(1)!;
      if (cls == '11') {
        return 'JEE 2026'; // special rule for class 11
      }
      return '$cls 2026'; // e.g. "6 2026", "7 2026"
    }

    // 2) Normal codes like 6C5, 7S3, 10G2, 11B1, etc.
    final classMatch = RegExp(
      r'^(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(grade);
    if (classMatch == null) return grade; // fallback
    final cls = classMatch.group(1)!;
    if (cls == '11') {
      return 'JEE'; // all 11… are JEE
    }
    return cls; // "6", "7", "8", "9", "10"
  }

  @override
  void initState() {
    super.initState();
    _loadInitialStats();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _statsService.dispose();
    super.dispose();
  }

  Future<void> _loadInitialStats() async {
    try {
      final stats = await _statsService.getCurrentStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToRealtime() {
    _statsService.subscribeToStats(
      onUpdate: (stats) {
        if (mounted) {
          setState(() {
            _stats = stats;
            _isSubscribed = true;
          });
        }
      },
      onError: (error) {
        print('Realtime error: $error');
        // Don't show error to user, just log it
        // Stats will still update on next manual refresh
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);

    return Scaffold(
      backgroundColor: _white,
      appBar: AppBar(
        title: Text(
          'Attendance Statistics',
          style: TextStyle(
            color: _white,
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 18 : 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.2),
        actions: [
          if (_isSubscribed)
            isMobile
                ? Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _accentColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.5),
                            blurRadius: 3,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _accentColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _accentColor.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Live',
                          style: TextStyle(
                            color: _white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _white,
              size: isMobile ? 20 : 24,
            ),
            onPressed: _showBatchFilterDialog,
            tooltip: 'Filter batches',
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            constraints: BoxConstraints(
              minWidth: isMobile ? 40 : 48,
              minHeight: isMobile ? 40 : 48,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: _white, size: isMobile ? 20 : 24),
            onPressed: _loadInitialStats,
            tooltip: 'Refresh stats',
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            constraints: BoxConstraints(
              minWidth: isMobile ? 40 : 48,
              minHeight: isMobile ? 40 : 48,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: _primaryColor,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading statistics...',
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Error loading stats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _loadInitialStats,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: _white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _stats != null
          ? SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCards(),
                      SizedBox(height: isMobile ? 24 : 32),
                      _buildBatchBreakdown(),
                      SizedBox(height: isMobile ? 16 : 24),
                      _buildLastUpdated(),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  void _showBatchFilterDialog() {
    final byBatch = _stats?['by_batch'] as Map<String, dynamic>?;
    if (byBatch == null || byBatch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No batches available to filter'),
          backgroundColor: _secondaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // Generate unique group labels from all batches
    final allBatches = byBatch.keys.toList();
    final gradeGroups = allBatches.map(classGroupFromGrade).toSet().toList()
      ..sort((a, b) {
        // Custom sort: numeric classes first (6, 7, 8, 9, 10), then JEE, then 2026 variants
        final aIsNumeric = RegExp(r'^\d+$').hasMatch(a);
        final bIsNumeric = RegExp(r'^\d+$').hasMatch(b);
        final aIs2026 = a.contains('2026');
        final bIs2026 = b.contains('2026');
        final aIsJEE = a.startsWith('JEE');
        final bIsJEE = b.startsWith('JEE');

        // Numeric classes come first, sorted numerically
        if (aIsNumeric && bIsNumeric) {
          return int.parse(a).compareTo(int.parse(b));
        }
        if (aIsNumeric) return -1;
        if (bIsNumeric) return 1;

        // JEE comes after numeric classes
        if (aIsJEE && !aIs2026 && bIsJEE && !bIs2026) return 0;
        if (aIsJEE && !aIs2026) return -1;
        if (bIsJEE && !bIs2026) return 1;

        // 2026 variants come last, sorted by their base class
        if (aIs2026 && bIs2026) {
          final aBase = a.replaceAll(' 2026', '');
          final bBase = b.replaceAll(' 2026', '');
          if (aBase == 'JEE' && bBase == 'JEE') return 0;
          if (aBase == 'JEE') return 1;
          if (bBase == 'JEE') return -1;
          if (RegExp(r'^\d+$').hasMatch(aBase) &&
              RegExp(r'^\d+$').hasMatch(bBase)) {
            return int.parse(aBase).compareTo(int.parse(bBase));
          }
          return aBase.compareTo(bBase);
        }
        if (aIs2026) return 1;
        if (bIs2026) return -1;

        // Fallback to alphabetical
        return a.compareTo(b);
      });

    // Add "All" option at the beginning
    final filterOptions = ['All', ...gradeGroups];
    String? tempSelected = _selectedGroup;

    final isMobile = _isMobile(context);

    if (isMobile) {
      // Use bottom sheet for mobile
      showModalBottomSheet(
        context: context,
        backgroundColor: _white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Filter by Group',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: tempSelected,
                        decoration: InputDecoration(
                          labelText: 'Select Group',
                          labelStyle: TextStyle(color: Colors.grey[700]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _primaryColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: filterOptions.map((group) {
                          return DropdownMenuItem<String>(
                            value: group == 'All' ? null : group,
                            child: Text(
                              group,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 16,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            tempSelected = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Groups are automatically mapped:\n'
                        '• "6 New" → "6 2026"\n'
                        '• "11 New" → "JEE 2026"\n'
                        '• "11B1" → "JEE"\n'
                        '• "6C1" → "6"',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedGroup = tempSelected;
                                  _hasAppliedFilter = tempSelected != null;
                                });
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: _white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Use dialog for desktop
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: _white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Filter by Group',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: tempSelected,
                    decoration: InputDecoration(
                      labelText: 'Select Group',
                      labelStyle: TextStyle(color: Colors.grey[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: filterOptions.map((group) {
                      return DropdownMenuItem<String>(
                        value: group == 'All' ? null : group,
                        child: Text(
                          group,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 15,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        tempSelected = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Groups are automatically mapped:\n'
                    '• "6 New" → "6 2026"\n'
                    '• "11 New" → "JEE 2026"\n'
                    '• "11B1" → "JEE"\n'
                    '• "6C1" → "6"',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedGroup = tempSelected;
                    _hasAppliedFilter = tempSelected != null;
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: _white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildOverviewCards() {
    final total = _stats!['total'] as int? ?? 0;
    final attended = _stats!['attended'] as int? ?? 0;
    final remaining = _stats!['remaining'] as int? ?? 0;
    final recent24h = _stats!['recent_24h'] as int? ?? 0;
    final percentage = _stats!['attendance_percentage'] as double? ?? 0.0;

    final isMobile = _isMobile(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Mobile: single column, Desktop: 2-3 columns based on width
    final crossAxisCount = isMobile
        ? 1
        : screenWidth >= 1200
        ? 3
        : 2;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: isMobile ? 12 : 20,
      mainAxisSpacing: isMobile ? 12 : 20,
      childAspectRatio: isMobile ? 2.0 : (screenWidth >= 768 ? 1.6 : 1.8),
      children: [
        _buildStatCard(
          title: 'Total Students',
          value: total.toString(),
          icon: Icons.people_outline,
          color: _primaryColor,
          gradient: [_primaryColor, _primaryColor.withOpacity(0.8)],
        ),
        _buildStatCard(
          title: 'Attended',
          value: attended.toString(),
          icon: Icons.check_circle_outline,
          color: _accentColor,
          gradient: [_accentColor, _accentColor.withOpacity(0.8)],
        ),
        _buildStatCard(
          title: 'Remaining',
          value: remaining.toString(),
          icon: Icons.pending_outlined,
          color: _secondaryColor,
          gradient: [_secondaryColor, _secondaryColor.withOpacity(0.8)],
        ),
        _buildStatCard(
          title: 'Attendance %',
          value: '${percentage.toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: _primaryColor,
          gradient: [_primaryColor, _primaryColor.withOpacity(0.8)],
        ),
        _buildStatCard(
          title: 'Last 24 Hours',
          value: recent24h.toString(),
          icon: Icons.access_time_outlined,
          color: _accentColor,
          gradient: [_accentColor, _accentColor.withOpacity(0.8)],
        ),
        _buildStatCard(
          title: 'Status',
          value: _isSubscribed ? 'Live' : 'Static',
          icon: _isSubscribed ? Icons.wifi_tethering : Icons.wifi_off,
          color: _isSubscribed ? _accentColor : Colors.grey,
          gradient: _isSubscribed
              ? [_accentColor, _accentColor.withOpacity(0.8)]
              : [Colors.grey, Colors.grey.withOpacity(0.8)],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
  }) {
    final isMobile = _isMobile(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _white,
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isMobile ? 20 : 24),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: isMobile ? 24 : 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchBreakdown() {
    final byBatch = _stats!['by_batch'] as Map<String, dynamic>?;

    if (byBatch == null || byBatch.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No batch data available',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Filter batches by group:
    // - If never filtered (_hasAppliedFilter = false) or _selectedGroup is null, show all
    // - Otherwise, filter by matching group label
    final filteredBatches = !_hasAppliedFilter || _selectedGroup == null
        ? byBatch.entries
              .toList() // Show all when not filtered
        : byBatch.entries
              .where(
                (entry) => classGroupFromGrade(entry.key) == _selectedGroup,
              )
              .toList();

    if (filteredBatches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.filter_alt_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No batches match the selected filter',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedGroup = null;
                    _hasAppliedFilter = false;
                  });
                },
                style: TextButton.styleFrom(foregroundColor: _primaryColor),
                child: const Text('Clear Filter'),
              ),
            ],
          ),
        ),
      );
    }

    final isMobile = _isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.groups_outlined,
                          color: _primaryColor,
                          size: isMobile ? 18 : 20,
                        ),
                      ),
                      SizedBox(width: isMobile ? 8 : 10),
                      Flexible(
                        child: Text(
                          'Batch Breakdown',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedGroup != null)
                  Flexible(
                    child: Container(
                      margin: EdgeInsets.only(left: isMobile ? 8 : 0),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 12,
                        vertical: isMobile ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: _secondaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _secondaryColor.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_alt,
                            color: _secondaryColor,
                            size: isMobile ? 12 : 14,
                          ),
                          SizedBox(width: isMobile ? 4 : 6),
                          Flexible(
                            child: Text(
                              isMobile
                                  ? _selectedGroup!
                                  : 'Group: $_selectedGroup',
                              style: TextStyle(
                                color: _secondaryColor,
                                fontSize: isMobile ? 11 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),
            isMobile
                ? _buildListLayout(filteredBatches)
                : _buildGridLayout(filteredBatches),
          ],
        ),
      ),
    );
  }

  Widget _buildGridLayout(List<MapEntry<String, dynamic>> batches) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 1600
        ? 4
        : screenWidth >= 1200
        ? 3
        : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
      ),
      itemCount: batches.length,
      itemBuilder: (context, index) {
        return _buildBatchCard(batches[index]);
      },
    );
  }

  Widget _buildListLayout(List<MapEntry<String, dynamic>> batches) {
    final isMobile = _isMobile(context);
    return Column(
      children: batches.map((entry) {
        return Padding(
          padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
          child: _buildBatchCard(entry),
        );
      }).toList(),
    );
  }

  Widget _buildBatchCard(MapEntry<String, dynamic> entry) {
    final isMobile = _isMobile(context);
    final batchName = entry.key;
    final batchData = entry.value as Map<String, dynamic>;
    final batchTotal = batchData['total'] as int? ?? 0;
    final batchAttended = batchData['attended'] as int? ?? 0;
    final batchRemaining = batchData['remaining'] as int? ?? 0;
    final batchPercentage = batchTotal > 0
        ? (batchAttended / batchTotal * 100)
        : 0.0;

    // Use palette colors based on percentage
    final progressColor = batchPercentage >= 75
        ? _accentColor
        : batchPercentage >= 50
        ? _primaryColor
        : _secondaryColor;

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: progressColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: progressColor.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 5 : 6),
                        decoration: BoxDecoration(
                          color: progressColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          color: progressColor,
                          size: isMobile ? 14 : 16,
                        ),
                      ),
                      SizedBox(width: isMobile ? 6 : 8),
                      Expanded(
                        child: Text(
                          batchName,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                            letterSpacing: 0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 10,
                    vertical: isMobile ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${batchPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.bold,
                      color: _white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 10 : 12),
            Stack(
              children: [
                Container(
                  height: isMobile ? 6 : 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: batchPercentage / 100,
                  child: Container(
                    height: isMobile ? 6 : 8,
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 10 : 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.check_circle,
                    label: 'Attended',
                    value: batchAttended.toString(),
                    total: batchTotal.toString(),
                    color: _accentColor,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 10),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.pending,
                    label: 'Remaining',
                    value: batchRemaining.toString(),
                    total: batchTotal.toString(),
                    color: _secondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required String total,
    required Color color,
  }) {
    final isMobile = _isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isMobile ? 14 : 16),
          SizedBox(width: isMobile ? 5 : 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    final isMobile = _isMobile(context);
    final timestamp = _stats!['timestamp'] as String?;
    if (timestamp == null) return const SizedBox();

    try {
      final dateTime = DateTime.parse(timestamp);
      final formatted =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
      final dateFormatted =
          '${dateTime.day}/${dateTime.month}/${dateTime.year}';

      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _accentColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.update, size: isMobile ? 12 : 14, color: _accentColor),
              SizedBox(width: isMobile ? 6 : 8),
              Flexible(
                child: Text(
                  isMobile
                      ? '$dateFormatted $formatted'
                      : 'Last updated: $dateFormatted at $formatted',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox();
    }
  }
}
