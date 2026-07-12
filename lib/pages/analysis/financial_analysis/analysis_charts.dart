import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_text_styles.dart';

class ChartPoint {
  final String label;
  final double value;
  final Color color;
  const ChartPoint(this.label, this.value, this.color);
}

/// عنصر رسم بياني موحّد يُستخدم في كل قسم "التحليل المالي" (الإيرادات،
/// المصروفات، تفاصيل البند). غلاف واحد فوق fl_chart حتى يسهل تغيير نوع
/// الرسم (أعمدة/خطي) مستقبلاً دون إعادة تصميم الصفحات التي تستدعيه.
class AnalysisBarChart extends StatelessWidget {
  final List<ChartPoint> points;
  final double height;

  const AnalysisBarChart({super.key, required this.points, this.height = 200});

  String _format(double v) => NumberFormat.compact().format(v);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text("لا توجد بيانات كافية للرسم", style: AppTextStyles.caption)));
    }
    final maxY = points.map((p) => p.value).fold(0.0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                _format(rod.toY),
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text(_format(v), style: const TextStyle(fontSize: 9, color: Colors.grey))),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(points[i].label, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
          ),
          barGroups: points.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [BarChartRodData(toY: e.value.value, color: e.value.color, width: 16, borderRadius: BorderRadius.circular(4))],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class LinePoint {
  final String label;
  final double value;
  const LinePoint(this.label, this.value);
}

/// رسم خطي لعرض اتجاه رقم عبر الزمن (الأرباح/التدفق النقدي/اتجاه بند مصروف).
class AnalysisLineChart extends StatelessWidget {
  final List<LinePoint> points;
  final Color color;
  final double height;

  const AnalysisLineChart({super.key, required this.points, required this.color, this.height = 180});

  String _format(double v) => NumberFormat.compact().format(v);

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(height: height, child: const Center(child: Text("لا توجد بيانات كافية لعرض الاتجاه", style: AppTextStyles.caption)));
    }
    final values = points.map((p) => p.value).toList();
    final maxY = values.fold(0.0, (a, b) => a > b ? a : b);
    final minY = values.fold(values.first, (a, b) => a < b ? a : b);
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY < 0 ? minY * 1.2 : 0,
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text(_format(v), style: const TextStyle(fontSize: 9, color: Colors.grey)))),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (points.length / 5).clamp(1, points.length).toDouble(),
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox();
                  return Text(points[i].label, style: const TextStyle(fontSize: 9, color: Colors.grey));
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(_format(s.y), const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
              isCurved: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.12)),
            ),
          ],
        ),
      ),
    );
  }
}
