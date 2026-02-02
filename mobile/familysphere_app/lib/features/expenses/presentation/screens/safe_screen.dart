import 'package:flutter/material.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';

class SafeScreen extends StatelessWidget {
  const SafeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family Safe'),
          bottom: TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Expenses'),
              Tab(text: 'Planning'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildExpensesTab(context),
            _buildPlanningTab(context),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildExpensesTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget Overview Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Spent this month',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '$2,450.80',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 150,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 3),
                            FlSpot(1, 1),
                            FlSpot(2, 4),
                            FlSpot(3, 2),
                            FlSpot(4, 5),
                            FlSpot(5, 3),
                            FlSpot(6, 4),
                          ],
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Recent Transactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(onPressed: () {}, child: const Text('See All')),
            ],
          ),
          const SizedBox(height: 16),
          _buildTransactionItem(
            context,
            title: 'Grocery Store',
            subtitle: 'Shopping • Today',
            amount: '-$120.50',
            icon: Icons.shopping_basket_rounded,
            color: Colors.orange,
          ),
          _buildTransactionItem(
            context,
            title: 'Electric Bill',
            subtitle: 'Utilities • Yesterday',
            amount: '-$85.00',
            icon: Icons.electrical_services_rounded,
            color: Colors.blue,
          ),
          _buildTransactionItem(
            context,
            title: 'Salary Deposit',
            subtitle: 'Income • 2 days ago',
            amount: '+$4,200.00',
            icon: Icons.account_balance_wallet_rounded,
            color: Colors.emerald,
            isPositive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildPlanningCard(
          context,
          title: 'Emergency Fund',
          progress: 0.65,
          target: '$10,000',
          current: '$6,500',
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        _buildPlanningCard(
          context,
          title: 'Family Vacation',
          progress: 0.3,
          target: '$5,000',
          current: '$1,500',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildTransactionItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    required Color color,
    bool isPositive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isPositive ? AppTheme.successColor : (isDark ? Colors.white : AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningCard(
    BuildContext context, {
    required String title,
    required double progress,
    required String target,
    required String current,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Icon(Icons.more_vert_rounded, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress', style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
              Text('$current / $target', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
