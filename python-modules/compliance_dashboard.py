#!/usr/bin/env python3
"""
Compliance Dashboard for GWOMBAT
Advanced compliance reporting and visualization with gap analysis

This module provides enhanced compliance dashboard functionality with
detailed gap analysis, remediation tracking, and executive reporting.
"""

import json
import sqlite3
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from pathlib import Path
from dataclasses import dataclass
from enum import Enum

# Optional dependencies for enhanced visualization
try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.progress import Progress, BarColumn, TextColumn
    from rich.text import Text
    from rich import box
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False

logger = logging.getLogger(__name__)

@dataclass
class ComplianceSummary:
    """Summary statistics for compliance assessment"""
    total_baselines: int
    compliant_count: int
    non_compliant_count: int
    manual_review_count: int
    unable_to_check_count: int
    compliance_percentage: float
    critical_gaps: int
    high_gaps: int
    medium_gaps: int
    low_gaps: int
    last_assessment: datetime

@dataclass
class ServiceCompliance:
    """Service-specific compliance status"""
    service_name: str
    total_baselines: int
    compliant_count: int
    non_compliant_count: int
    compliance_percentage: float
    critical_issues: int
    risk_score: int

@dataclass
class RemediationItem:
    """Remediation tracking item"""
    id: int
    baseline_id: str
    title: str
    description: str
    priority: str
    effort: str
    status: str
    assigned_to: Optional[str]
    target_date: Optional[datetime]
    business_impact: str

class ComplianceDashboard:
    """
    Advanced compliance dashboard with gap analysis and remediation tracking
    
    Provides comprehensive compliance reporting, visualization, and remediation
    management for GWOMBAT SCuBA compliance assessments.
    """
    
    def __init__(self, db_path: str = "./config/gwombat.db"):
        """
        Initialize compliance dashboard
        
        Args:
            db_path: Path to GWOMBAT database
        """
        self.db_path = Path(db_path)
        self.session_id = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_dashboard_{id(self)}"
        
        # Initialize console for rich output if available
        self.console = Console() if RICH_AVAILABLE else None
        
        logger.info("Compliance dashboard initialized")

    def get_overall_compliance_summary(self) -> Optional[ComplianceSummary]:
        """Get overall compliance summary statistics"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                
                # Get latest compliance results
                cursor = conn.execute("""
                    SELECT 
                        COUNT(*) as total_baselines,
                        SUM(CASE WHEN compliance_status = 'compliant' THEN 1 ELSE 0 END) as compliant_count,
                        SUM(CASE WHEN compliance_status = 'non_compliant' THEN 1 ELSE 0 END) as non_compliant_count,
                        SUM(CASE WHEN compliance_status = 'manual_review' THEN 1 ELSE 0 END) as manual_review_count,
                        SUM(CASE WHEN compliance_status = 'unable_to_check' THEN 1 ELSE 0 END) as unable_to_check_count,
                        SUM(CASE WHEN compliance_status = 'non_compliant' AND risk_level = 'critical' THEN 1 ELSE 0 END) as critical_gaps,
                        SUM(CASE WHEN compliance_status = 'non_compliant' AND risk_level = 'high' THEN 1 ELSE 0 END) as high_gaps,
                        SUM(CASE WHEN compliance_status = 'non_compliant' AND risk_level = 'medium' THEN 1 ELSE 0 END) as medium_gaps,
                        SUM(CASE WHEN compliance_status = 'non_compliant' AND risk_level = 'low' THEN 1 ELSE 0 END) as low_gaps,
                        MAX(assessment_date) as last_assessment
                    FROM scuba_latest_compliance
                    WHERE compliance_status IS NOT NULL
                """)
                
                row = cursor.fetchone()
                if not row or row['total_baselines'] == 0:
                    return None
                
                # Calculate compliance percentage
                assessable = row['compliant_count'] + row['non_compliant_count']
                compliance_percentage = (row['compliant_count'] / assessable * 100) if assessable > 0 else 0
                
                return ComplianceSummary(
                    total_baselines=row['total_baselines'],
                    compliant_count=row['compliant_count'],
                    non_compliant_count=row['non_compliant_count'],
                    manual_review_count=row['manual_review_count'],
                    unable_to_check_count=row['unable_to_check_count'],
                    compliance_percentage=round(compliance_percentage, 1),
                    critical_gaps=row['critical_gaps'],
                    high_gaps=row['high_gaps'],
                    medium_gaps=row['medium_gaps'],
                    low_gaps=row['low_gaps'],
                    last_assessment=datetime.fromisoformat(row['last_assessment']) if row['last_assessment'] else None
                )
                
        except Exception as e:
            logger.error(f"Error getting compliance summary: {e}")
            return None

    def get_service_compliance_breakdown(self) -> List[ServiceCompliance]:
        """Get compliance breakdown by service"""
        services = []
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                
                cursor = conn.execute("""
                    SELECT 
                        service_name,
                        COUNT(*) as total_baselines,
                        SUM(CASE WHEN compliance_status = 'compliant' THEN 1 ELSE 0 END) as compliant_count,
                        SUM(CASE WHEN compliance_status = 'non_compliant' THEN 1 ELSE 0 END) as non_compliant_count,
                        SUM(CASE WHEN compliance_status = 'non_compliant' AND risk_level = 'critical' THEN 1 ELSE 0 END) as critical_issues
                    FROM scuba_latest_compliance
                    WHERE compliance_status IN ('compliant', 'non_compliant')
                    GROUP BY service_name
                    ORDER BY service_name
                """)
                
                for row in cursor.fetchall():
                    assessable = row['compliant_count'] + row['non_compliant_count']
                    compliance_percentage = (row['compliant_count'] / assessable * 100) if assessable > 0 else 0
                    
                    # Simple risk score calculation (0-100, higher = more risk)
                    risk_score = min(100, (row['non_compliant_count'] * 10) + (row['critical_issues'] * 25))
                    
                    services.append(ServiceCompliance(
                        service_name=row['service_name'],
                        total_baselines=row['total_baselines'],
                        compliant_count=row['compliant_count'],
                        non_compliant_count=row['non_compliant_count'],
                        compliance_percentage=round(compliance_percentage, 1),
                        critical_issues=row['critical_issues'],
                        risk_score=risk_score
                    ))
                    
        except Exception as e:
            logger.error(f"Error getting service compliance breakdown: {e}")
        
        return services

    def get_compliance_trends(self, days: int = 30) -> Dict[str, Any]:
        """Get compliance trends over specified number of days"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                
                # Get assessment history
                cursor = conn.execute("""
                    SELECT 
                        assessment_start,
                        overall_compliance_percentage,
                        critical_findings,
                        baselines_assessed
                    FROM scuba_assessment_history
                    WHERE assessment_start >= datetime('now', '-{} days')
                    ORDER BY assessment_start ASC
                """.format(days))
                
                assessments = cursor.fetchall()
                
                if not assessments:
                    return {"message": "No assessment history available"}
                
                # Calculate trends
                compliance_trend = []
                critical_trend = []
                dates = []
                
                for assessment in assessments:
                    dates.append(assessment['assessment_start'])
                    compliance_trend.append(assessment['overall_compliance_percentage'])
                    critical_trend.append(assessment['critical_findings'])
                
                # Calculate trend direction
                if len(compliance_trend) >= 2:
                    compliance_direction = "improving" if compliance_trend[-1] > compliance_trend[0] else "declining"
                    critical_direction = "improving" if critical_trend[-1] < critical_trend[0] else "worsening"
                else:
                    compliance_direction = "stable"
                    critical_direction = "stable"
                
                return {
                    "assessment_count": len(assessments),
                    "date_range": f"{dates[0]} to {dates[-1]}" if dates else None,
                    "compliance_trend": {
                        "direction": compliance_direction,
                        "current": compliance_trend[-1] if compliance_trend else 0,
                        "previous": compliance_trend[0] if compliance_trend else 0,
                        "change": compliance_trend[-1] - compliance_trend[0] if len(compliance_trend) >= 2 else 0
                    },
                    "critical_findings_trend": {
                        "direction": critical_direction,
                        "current": critical_trend[-1] if critical_trend else 0,
                        "previous": critical_trend[0] if critical_trend else 0,
                        "change": critical_trend[-1] - critical_trend[0] if len(critical_trend) >= 2 else 0
                    }
                }
                
        except Exception as e:
            logger.error(f"Error getting compliance trends: {e}")
            return {"error": str(e)}

    def get_remediation_items(self, status_filter: Optional[str] = None, 
                            priority_filter: Optional[str] = None) -> List[RemediationItem]:
        """Get remediation items with optional filtering"""
        items = []
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                
                query = """
                    SELECT 
                        id, baseline_id, gap_title, gap_description, remediation_priority,
                        remediation_effort, status, assigned_to, target_date, business_impact
                    FROM scuba_remediation_items
                    WHERE 1=1
                """
                params = []
                
                if status_filter:
                    query += " AND status = ?"
                    params.append(status_filter)
                
                if priority_filter:
                    query += " AND remediation_priority = ?"
                    params.append(priority_filter)
                
                query += " ORDER BY CASE remediation_priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, target_date ASC"
                
                cursor = conn.execute(query, params)
                
                for row in cursor.fetchall():
                    target_date = None
                    if row['target_date']:
                        try:
                            target_date = datetime.fromisoformat(row['target_date'])
                        except:
                            pass
                    
                    items.append(RemediationItem(
                        id=row['id'],
                        baseline_id=row['baseline_id'],
                        title=row['gap_title'],
                        description=row['gap_description'],
                        priority=row['remediation_priority'],
                        effort=row['remediation_effort'],
                        status=row['status'],
                        assigned_to=row['assigned_to'],
                        target_date=target_date,
                        business_impact=row['business_impact']
                    ))
                    
        except Exception as e:
            logger.error(f"Error getting remediation items: {e}")
        
        return items

    def get_critical_gaps_analysis(self) -> Dict[str, Any]:
        """Get detailed analysis of critical compliance gaps"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                
                # Get critical compliance gaps
                cursor = conn.execute("""
                    SELECT 
                        b.service_name,
                        b.baseline_id,
                        b.baseline_title,
                        b.baseline_description,
                        r.gap_description,
                        r.current_value,
                        r.expected_value,
                        r.assessment_date,
                        b.remediation_steps
                    FROM scuba_latest_compliance l
                    JOIN scuba_baselines b ON l.baseline_id = b.baseline_id
                    LEFT JOIN scuba_compliance_results r ON l.baseline_id = r.baseline_id 
                        AND r.assessment_date = l.assessment_date
                    WHERE l.compliance_status = 'non_compliant' 
                    AND l.risk_level = 'critical'
                    ORDER BY b.service_name, b.baseline_id
                """)
                
                critical_gaps = []
                service_breakdown = {}
                
                for row in cursor.fetchall():
                    gap_info = {
                        "baseline_id": row['baseline_id'],
                        "baseline_title": row['baseline_title'],
                        "service_name": row['service_name'],
                        "gap_description": row['gap_description'],
                        "current_value": row['current_value'],
                        "expected_value": row['expected_value'],
                        "remediation_steps": row['remediation_steps'],
                        "assessment_date": row['assessment_date']
                    }
                    
                    critical_gaps.append(gap_info)
                    
                    # Service breakdown
                    if row['service_name'] not in service_breakdown:
                        service_breakdown[row['service_name']] = 0
                    service_breakdown[row['service_name']] += 1
                
                return {
                    "total_critical_gaps": len(critical_gaps),
                    "critical_gaps": critical_gaps,
                    "service_breakdown": service_breakdown,
                    "analysis_date": datetime.now().isoformat()
                }
                
        except Exception as e:
            logger.error(f"Error getting critical gaps analysis: {e}")
            return {"error": str(e)}

    def generate_executive_summary(self) -> Dict[str, Any]:
        """Generate executive-level compliance summary"""
        summary = {
            "report_date": datetime.now().isoformat(),
            "report_type": "Executive Compliance Summary"
        }
        
        # Overall compliance
        overall = self.get_overall_compliance_summary()
        if overall:
            summary["overall_compliance"] = {
                "compliance_percentage": overall.compliance_percentage,
                "total_baselines": overall.total_baselines,
                "critical_gaps": overall.critical_gaps,
                "high_priority_gaps": overall.high_gaps,
                "last_assessment": overall.last_assessment.isoformat() if overall.last_assessment else None
            }
        
        # Service breakdown
        services = self.get_service_compliance_breakdown()
        summary["service_compliance"] = [
            {
                "service": svc.service_name,
                "compliance_percentage": svc.compliance_percentage,
                "critical_issues": svc.critical_issues,
                "risk_score": svc.risk_score
            }
            for svc in services
        ]
        
        # Critical gaps
        critical_analysis = self.get_critical_gaps_analysis()
        summary["critical_gaps_summary"] = {
            "total_critical_gaps": critical_analysis.get("total_critical_gaps", 0),
            "affected_services": list(critical_analysis.get("service_breakdown", {}).keys())
        }
        
        # Trends
        trends = self.get_compliance_trends(30)
        summary["trends"] = trends
        
        # Remediation status
        open_remediations = len(self.get_remediation_items(status_filter="open"))
        in_progress_remediations = len(self.get_remediation_items(status_filter="in_progress"))
        
        summary["remediation_status"] = {
            "open_items": open_remediations,
            "in_progress_items": in_progress_remediations
        }
        
        return summary

    def display_compliance_dashboard(self) -> None:
        """Display interactive compliance dashboard"""
        if not RICH_AVAILABLE:
            self._display_basic_dashboard()
            return
        
        console = self.console
        console.clear()
        
        # Header
        console.print(Panel.fit(
            "🔐 GWOMBAT SCuBA Compliance Dashboard",
            style="bold blue"
        ))
        
        # Overall compliance summary
        overall = self.get_overall_compliance_summary()
        if overall:
            # Compliance percentage with color coding
            if overall.compliance_percentage >= 90:
                compliance_color = "green"
            elif overall.compliance_percentage >= 75:
                compliance_color = "yellow"
            else:
                compliance_color = "red"
            
            summary_table = Table(title="Overall Compliance Status", box=box.ROUNDED)
            summary_table.add_column("Metric", style="cyan")
            summary_table.add_column("Value", justify="right")
            
            summary_table.add_row("Compliance Percentage", 
                                 f"[{compliance_color}]{overall.compliance_percentage:.1f}%[/{compliance_color}]")
            summary_table.add_row("Total Baselines", str(overall.total_baselines))
            summary_table.add_row("Compliant", f"[green]{overall.compliant_count}[/green]")
            summary_table.add_row("Non-Compliant", f"[red]{overall.non_compliant_count}[/red]")
            summary_table.add_row("Critical Gaps", f"[bold red]{overall.critical_gaps}[/bold red]")
            summary_table.add_row("High Priority Gaps", f"[red]{overall.high_gaps}[/red]")
            summary_table.add_row("Last Assessment", 
                                 overall.last_assessment.strftime("%Y-%m-%d %H:%M") if overall.last_assessment else "Never")
            
            console.print(summary_table)
            console.print()
        
        # Service compliance breakdown
        services = self.get_service_compliance_breakdown()
        if services:
            service_table = Table(title="Service Compliance Breakdown", box=box.ROUNDED)
            service_table.add_column("Service", style="cyan")
            service_table.add_column("Compliance %", justify="right")
            service_table.add_column("Compliant", justify="right", style="green")
            service_table.add_column("Non-Compliant", justify="right", style="red")
            service_table.add_column("Critical Issues", justify="right", style="bold red")
            service_table.add_column("Risk Score", justify="right")
            
            for svc in services:
                risk_color = "green" if svc.risk_score <= 25 else "yellow" if svc.risk_score <= 50 else "red"
                service_table.add_row(
                    svc.service_name.title(),
                    f"{svc.compliance_percentage:.1f}%",
                    str(svc.compliant_count),
                    str(svc.non_compliant_count),
                    str(svc.critical_issues),
                    f"[{risk_color}]{svc.risk_score}[/{risk_color}]"
                )
            
            console.print(service_table)
            console.print()
        
        # Critical gaps summary
        critical_analysis = self.get_critical_gaps_analysis()
        if critical_analysis.get("total_critical_gaps", 0) > 0:
            console.print(Panel(
                f"🚨 {critical_analysis['total_critical_gaps']} Critical Compliance Gaps Require Immediate Attention",
                style="bold red"
            ))
            console.print()
        
        # Remediation summary
        open_items = self.get_remediation_items(status_filter="open")
        in_progress_items = self.get_remediation_items(status_filter="in_progress")
        
        remediation_table = Table(title="Remediation Status", box=box.ROUNDED)
        remediation_table.add_column("Status", style="cyan")
        remediation_table.add_column("Count", justify="right")
        remediation_table.add_column("Critical", justify="right", style="red")
        remediation_table.add_column("High", justify="right", style="yellow")
        
        open_critical = len([item for item in open_items if item.priority == "critical"])
        open_high = len([item for item in open_items if item.priority == "high"])
        progress_critical = len([item for item in in_progress_items if item.priority == "critical"])
        progress_high = len([item for item in in_progress_items if item.priority == "high"])
        
        remediation_table.add_row("Open", str(len(open_items)), str(open_critical), str(open_high))
        remediation_table.add_row("In Progress", str(len(in_progress_items)), str(progress_critical), str(progress_high))
        
        console.print(remediation_table)

    def _display_basic_dashboard(self) -> None:
        """Display basic text-based dashboard when rich is not available"""
        print("\n" + "="*60)
        print("🔐 GWOMBAT SCuBA Compliance Dashboard")
        print("="*60)
        
        # Overall compliance
        overall = self.get_overall_compliance_summary()
        if overall:
            print(f"\nOverall Compliance: {overall.compliance_percentage:.1f}%")
            print(f"Total Baselines: {overall.total_baselines}")
            print(f"Compliant: {overall.compliant_count}")
            print(f"Non-Compliant: {overall.non_compliant_count}")
            print(f"Critical Gaps: {overall.critical_gaps}")
            print(f"High Priority Gaps: {overall.high_gaps}")
            if overall.last_assessment:
                print(f"Last Assessment: {overall.last_assessment.strftime('%Y-%m-%d %H:%M')}")
        
        # Service breakdown
        services = self.get_service_compliance_breakdown()
        if services:
            print(f"\nService Compliance Breakdown:")
            print("-" * 60)
            for svc in services:
                print(f"{svc.service_name.ljust(15)}: {svc.compliance_percentage:5.1f}% "
                      f"({svc.compliant_count}/{svc.compliant_count + svc.non_compliant_count}) "
                      f"Critical: {svc.critical_issues}")
        
        # Critical gaps
        critical_analysis = self.get_critical_gaps_analysis()
        if critical_analysis.get("total_critical_gaps", 0) > 0:
            print(f"\n⚠️  {critical_analysis['total_critical_gaps']} Critical Compliance Gaps Require Attention")
        
        print("\n" + "="*60)

    def export_compliance_report(self, output_path: str, format: str = "json") -> bool:
        """Export comprehensive compliance report"""
        try:
            # Generate comprehensive report data
            report_data = {
                "metadata": {
                    "report_generated": datetime.now().isoformat(),
                    "report_type": "SCuBA Compliance Report",
                    "gwombat_version": "3.0.0-hybrid"
                },
                "executive_summary": self.generate_executive_summary(),
                "detailed_compliance": {
                    "overall_summary": self.get_overall_compliance_summary(),
                    "service_breakdown": self.get_service_compliance_breakdown(),
                    "critical_gaps": self.get_critical_gaps_analysis(),
                    "trends": self.get_compliance_trends(30)
                },
                "remediation": {
                    "open_items": self.get_remediation_items(status_filter="open"),
                    "in_progress_items": self.get_remediation_items(status_filter="in_progress"),
                    "critical_priority": self.get_remediation_items(priority_filter="critical")
                }
            }
            
            # Convert dataclasses to dicts for JSON serialization
            def convert_dataclass(obj):
                if hasattr(obj, '__dict__'):
                    result = {}
                    for key, value in obj.__dict__.items():
                        if isinstance(value, datetime):
                            result[key] = value.isoformat()
                        elif isinstance(value, list):
                            result[key] = [convert_dataclass(item) for item in value]
                        else:
                            result[key] = value
                    return result
                return obj
            
            # Clean up dataclasses
            for section in report_data["detailed_compliance"]:
                if isinstance(report_data["detailed_compliance"][section], list):
                    report_data["detailed_compliance"][section] = [
                        convert_dataclass(item) for item in report_data["detailed_compliance"][section]
                    ]
                elif hasattr(report_data["detailed_compliance"][section], '__dict__'):
                    report_data["detailed_compliance"][section] = convert_dataclass(
                        report_data["detailed_compliance"][section]
                    )
            
            for section in report_data["remediation"]:
                report_data["remediation"][section] = [
                    convert_dataclass(item) for item in report_data["remediation"][section]
                ]
            
            # Write report
            output_file = Path(output_path)
            output_file.parent.mkdir(parents=True, exist_ok=True)
            
            if format.lower() == "json":
                with open(output_file, 'w') as f:
                    json.dump(report_data, f, indent=2, default=str)
            else:
                logger.error(f"Unsupported output format: {format}")
                return False
            
            logger.info(f"Compliance report exported to {output_file}")
            return True
            
        except Exception as e:
            logger.error(f"Error exporting compliance report: {e}")
            return False

def main():
    """Command-line interface for compliance dashboard"""
    import argparse
    
    parser = argparse.ArgumentParser(description="GWOMBAT Compliance Dashboard")
    parser.add_argument("--db-path", default="./config/gwombat.db", help="Path to GWOMBAT database")
    parser.add_argument("--action", choices=["dashboard", "export", "summary"], 
                       default="dashboard", help="Action to perform")
    parser.add_argument("--output", help="Output file path for export")
    parser.add_argument("--format", choices=["json"], default="json", help="Export format")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Initialize dashboard
    dashboard = ComplianceDashboard(args.db_path)
    
    # Perform requested action
    if args.action == "dashboard":
        dashboard.display_compliance_dashboard()
    
    elif args.action == "export":
        if not args.output:
            print("Error: --output required for export action")
            return 1
        
        success = dashboard.export_compliance_report(args.output, args.format)
        if success:
            print(f"✓ Compliance report exported to {args.output}")
        else:
            print("✗ Failed to export compliance report")
            return 1
    
    elif args.action == "summary":
        summary = dashboard.generate_executive_summary()
        print(json.dumps(summary, indent=2, default=str))
    
    return 0

if __name__ == "__main__":
    exit(main())