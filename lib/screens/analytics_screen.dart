import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _analyticsService = AnalyticsService();

  bool _loading = true;
  int _totalSeconds7Days = 0;
  int _totalPagesMonth = 0;
  List<Map<String, dynamic>> _dailyData = [];
  List<Map<String, dynamic>> _monthlyData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _analyticsService.totalSecondsLast7Days(),
      _analyticsService.totalPagesThisMonth(),
      _analyticsService.dailyBreakdownLast7Days(),
      _analyticsService.monthlyBreakdown(),
    ]);
    if (mounted) {
      setState(() {
        _totalSeconds7Days = results[0] as int;
        _totalPagesMonth = results[1] as int;
        _dailyData = results[2] as List<Map<String, dynamic>>;
        _monthlyData = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    }
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reading Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white60),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF6C63FF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary cards
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.access_time_rounded,
                          label: 'Last 7 Days',
                          value: _formatTime(_totalSeconds7Days),
                          color: const Color(0xFF6C63FF),
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.menu_book_rounded,
                          label: 'Pages This Month',
                          value: '$_totalPagesMonth',
                          color: const Color(0xFF4ECDC4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Daily Bar Chart
                    const _SectionTitle(title: 'Minutes Read — Last 7 Days'),
                    const SizedBox(height: 12),
                    if (_dailyData.isEmpty)
                      const _EmptyChart(message: 'No reading data for the past 7 days.')
                    else
                      _DailyBarChart(data: _dailyData),

                    const SizedBox(height: 28),

                    // Monthly Line Chart
                    const _SectionTitle(title: 'Page Volume Over Time'),
                    const SizedBox(height: 12),
                    if (_monthlyData.isEmpty)
                      const _EmptyChart(message: 'No monthly data available yet.')
                    else
                      _MonthlyLineChart(data: _monthlyData),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white24, fontSize: 13),
        ),
      ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _DailyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxY = data
        .map((d) => (d['minutes'] as double))
        .fold(0.0, (a, b) => a > b ? a : b);

    final bars = data.asMap().entries.map((e) {
      final minutes = (e.value['minutes'] as double);
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: minutes,
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFA29BFE)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 10 : maxY * 1.3,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}m',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final date = data[idx]['date'] as String;
                  final parts = date.split('-');
                  final label = parts.length == 3
                      ? '${parts[1]}/${parts[2]}'
                      : date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: bars,
        ),
      ),
    );
  }
}

class _MonthlyLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _MonthlyLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) {
      final pages = (e.value['pages'] as int).toDouble();
      return FlSpot(e.key.toDouble(), pages);
    }).toList();

    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 10 : maxY * 1.3,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}p',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final month = data[idx]['month'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      month.length >= 7 ? month.substring(5) : month,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF74B9FF)],
              ),
              barWidth: 2.5,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4ECDC4).withValues(alpha: 0.2),
                    const Color(0xFF74B9FF).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF4ECDC4),
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF0F1117),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}