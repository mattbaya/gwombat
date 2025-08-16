#!/usr/bin/env python3
"""
SCuBA Compliance Module for GWOMBAT
CISA Secure Cloud Business Applications (SCuBA) Security Baselines Implementation

This module implements comprehensive Google Workspace security baseline compliance
checking based on CISA's SCuBA guidelines, supporting all 9 GWS services with
configurable enable/disable controls.
"""

import json
import sqlite3
import logging
import subprocess
import yaml
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from pathlib import Path
from dataclasses import dataclass, asdict
from enum import Enum

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ComplianceStatus(Enum):
    """Compliance assessment result statuses"""
    COMPLIANT = "compliant"
    NON_COMPLIANT = "non_compliant"
    NOT_APPLICABLE = "not_applicable"
    UNABLE_TO_CHECK = "unable_to_check"
    MANUAL_REVIEW = "manual_review"

class CriticalityLevel(Enum):
    """CISA baseline criticality levels"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class CheckType(Enum):
    """Types of compliance checks"""
    CONFIGURATION = "configuration"
    AUDIT_LOG = "audit_log"
    API_CHECK = "api_check"
    MANUAL = "manual"

@dataclass
class ComplianceResult:
    """Individual compliance check result"""
    baseline_id: str
    service_name: str
    compliance_status: ComplianceStatus
    confidence_level: str
    current_value: Optional[str]
    expected_value: Optional[str]
    gap_description: Optional[str]
    risk_level: str
    evidence_data: Dict[str, Any]
    check_method: str
    assessment_date: datetime

@dataclass
class ScubaBaseline:
    """CISA SCuBA baseline definition"""
    baseline_id: str
    service_name: str
    baseline_title: str
    baseline_description: str
    requirement_text: str
    criticality_level: CriticalityLevel
    compliance_check_type: CheckType
    gam_command: Optional[str]
    api_endpoint: Optional[str]
    expected_value: Optional[str]
    check_logic: Dict[str, Any]
    remediation_steps: str
    reference_links: List[str]
    is_enabled: bool

class ScubaCompliance:
    """
    Main SCuBA compliance engine for GWOMBAT
    
    Provides comprehensive CISA baseline compliance checking for Google Workspace
    with database integration and configurable assessment capabilities.
    """
    
    def __init__(self, db_path: str = "./config/gwombat.db", gam_path: str = "gam"):
        """
        Initialize SCuBA compliance engine
        
        Args:
            db_path: Path to GWOMBAT SQLite database
            gam_path: Path to GAM executable
        """
        self.db_path = Path(db_path)
        self.gam_path = gam_path
        self.session_id = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_scuba_{id(self)}"
        
        # Load configuration
        self._load_config()
        
        # Initialize database connection
        self._init_database()
        
        # Load baseline definitions
        self.baselines = self._load_baselines()
        
        logger.info(f"SCuBA Compliance engine initialized with {len(self.baselines)} baselines")

    def _load_config(self) -> None:
        """Load configuration from database and environment"""
        # This will be enhanced to read from database configuration
        self.config = {
            'api_timeout': 30,
            'max_retries': 3,
            'batch_size': 10,
            'parallel_checks': True
        }

    def _init_database(self) -> None:
        """Initialize database connection and ensure schema exists"""
        try:
            self.db_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Initialize SCuBA schema if needed
            schema_path = Path(__file__).parent.parent / "scuba_compliance_schema.sql"
            if schema_path.exists():
                with sqlite3.connect(self.db_path) as conn:
                    with open(schema_path, 'r') as f:
                        conn.executescript(f.read())
                logger.info("SCuBA compliance database schema initialized")
            else:
                logger.warning("SCuBA schema file not found - database may not be properly initialized")
                
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
            raise

    def _load_baselines(self) -> List[ScubaBaseline]:
        """Load baseline definitions from database"""
        baselines = []
        
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.execute("""
                    SELECT * FROM scuba_baselines 
                    WHERE is_enabled = 1
                    ORDER BY service_name, criticality_level DESC, baseline_id
                """)
                
                for row in cursor.fetchall():
                    baseline = ScubaBaseline(
                        baseline_id=row['baseline_id'],
                        service_name=row['service_name'],
                        baseline_title=row['baseline_title'],
                        baseline_description=row['baseline_description'],
                        requirement_text=row['requirement_text'],
                        criticality_level=CriticalityLevel(row['criticality_level']),
                        compliance_check_type=CheckType(row['compliance_check_type']),
                        gam_command=row['gam_command'],
                        api_endpoint=row['api_endpoint'],
                        expected_value=row['expected_value'],
                        check_logic=json.loads(row['check_logic']) if row['check_logic'] else {},
                        remediation_steps=row['remediation_steps'],
                        reference_links=json.loads(row['reference_links']) if row['reference_links'] else [],
                        is_enabled=bool(row['is_enabled'])
                    )
                    baselines.append(baseline)
                    
        except Exception as e:
            logger.error(f"Failed to load baselines from database: {e}")
            # Return empty list - will be handled by caller
            
        return baselines

    def is_service_enabled(self, service_name: str) -> bool:
        """Check if compliance checking is enabled for a specific service"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute("""
                    SELECT is_enabled FROM scuba_feature_config 
                    WHERE feature_category = 'service' AND feature_name = ?
                """, (service_name,))
                
                result = cursor.fetchone()
                return bool(result[0]) if result else False
                
        except Exception as e:
            logger.error(f"Error checking service enablement for {service_name}: {e}")
            return False

    def execute_gam_command(self, command: str) -> Tuple[bool, str, str]:
        """
        Execute GAM command safely and return results
        
        Args:
            command: GAM command to execute
            
        Returns:
            Tuple of (success, stdout, stderr)
        """
        try:
            # Ensure GAM command is properly formatted
            if not command.startswith(self.gam_path):
                command = f"{self.gam_path} {command}"
            
            logger.debug(f"Executing GAM command: {command}")
            
            result = subprocess.run(
                command.split(),
                capture_output=True,
                text=True,
                timeout=self.config['api_timeout']
            )
            
            return (result.returncode == 0, result.stdout, result.stderr)
            
        except subprocess.TimeoutExpired:
            logger.error(f"GAM command timed out: {command}")
            return (False, "", "Command timed out")
        except Exception as e:
            logger.error(f"GAM command execution failed: {e}")
            return (False, "", str(e))

    def check_baseline_compliance(self, baseline: ScubaBaseline) -> ComplianceResult:
        """
        Check compliance for a single baseline
        
        Args:
            baseline: ScubaBaseline to check
            
        Returns:
            ComplianceResult with assessment details
        """
        logger.info(f"Checking compliance for {baseline.baseline_id}: {baseline.baseline_title}")
        
        # Check if service is enabled
        if not self.is_service_enabled(baseline.service_name):
            return ComplianceResult(
                baseline_id=baseline.baseline_id,
                service_name=baseline.service_name,
                compliance_status=ComplianceStatus.NOT_APPLICABLE,
                confidence_level="high",
                current_value=None,
                expected_value=baseline.expected_value,
                gap_description="Service compliance checking is disabled",
                risk_level="low",
                evidence_data={"reason": "service_disabled"},
                check_method="configuration_check",
                assessment_date=datetime.now()
            )

        # Execute baseline-specific compliance check
        if baseline.compliance_check_type == CheckType.CONFIGURATION:
            return self._check_configuration_baseline(baseline)
        elif baseline.compliance_check_type == CheckType.AUDIT_LOG:
            return self._check_audit_log_baseline(baseline)
        elif baseline.compliance_check_type == CheckType.API_CHECK:
            return self._check_api_baseline(baseline)
        elif baseline.compliance_check_type == CheckType.MANUAL:
            return self._check_manual_baseline(baseline)
        else:
            return self._create_error_result(baseline, "Unknown check type")

    def _check_configuration_baseline(self, baseline: ScubaBaseline) -> ComplianceResult:
        """Check configuration-based baseline using GAM commands"""
        if not baseline.gam_command:
            return self._create_error_result(baseline, "No GAM command specified")
        
        success, stdout, stderr = self.execute_gam_command(baseline.gam_command)
        
        if not success:
            return ComplianceResult(
                baseline_id=baseline.baseline_id,
                service_name=baseline.service_name,
                compliance_status=ComplianceStatus.UNABLE_TO_CHECK,
                confidence_level="low",
                current_value=None,
                expected_value=baseline.expected_value,
                gap_description=f"GAM command failed: {stderr}",
                risk_level="medium",
                evidence_data={"gam_error": stderr, "command": baseline.gam_command},
                check_method="gam_command",
                assessment_date=datetime.now()
            )

        # Parse GAM output and determine compliance
        return self._evaluate_compliance(baseline, stdout)

    def _check_audit_log_baseline(self, baseline: ScubaBaseline) -> ComplianceResult:
        """Check audit log-based baseline"""
        # Implementation for audit log analysis
        logger.info(f"Audit log check for {baseline.baseline_id} - implementation pending")
        
        return ComplianceResult(
            baseline_id=baseline.baseline_id,
            service_name=baseline.service_name,
            compliance_status=ComplianceStatus.MANUAL_REVIEW,
            confidence_level="medium",
            current_value=None,
            expected_value=baseline.expected_value,
            gap_description="Audit log analysis requires manual review",
            risk_level="medium",
            evidence_data={"note": "audit_log_analysis_pending"},
            check_method="audit_log_analysis",
            assessment_date=datetime.now()
        )

    def _check_api_baseline(self, baseline: ScubaBaseline) -> ComplianceResult:
        """Check API-based baseline using Google Workspace APIs"""
        # Implementation for direct API calls
        logger.info(f"API check for {baseline.baseline_id} - implementation pending")
        
        return ComplianceResult(
            baseline_id=baseline.baseline_id,
            service_name=baseline.service_name,
            compliance_status=ComplianceStatus.MANUAL_REVIEW,
            confidence_level="medium",
            current_value=None,
            expected_value=baseline.expected_value,
            gap_description="Direct API check requires implementation",
            risk_level="medium",
            evidence_data={"note": "api_check_pending"},
            check_method="api_call",
            assessment_date=datetime.now()
        )

    def _check_manual_baseline(self, baseline: ScubaBaseline) -> ComplianceResult:
        """Handle manual review baselines"""
        return ComplianceResult(
            baseline_id=baseline.baseline_id,
            service_name=baseline.service_name,
            compliance_status=ComplianceStatus.MANUAL_REVIEW,
            confidence_level="low",
            current_value=None,
            expected_value=baseline.expected_value,
            gap_description="Manual review required - no automated check available",
            risk_level=baseline.criticality_level.value,
            evidence_data={"manual_review_required": True},
            check_method="manual",
            assessment_date=datetime.now()
        )

    def _evaluate_compliance(self, baseline: ScubaBaseline, gam_output: str) -> ComplianceResult:
        """
        Evaluate compliance based on GAM output and baseline expectations
        
        This is a simplified implementation - would be enhanced with specific
        logic for each baseline type.
        """
        current_value = gam_output.strip()
        expected_value = baseline.expected_value
        
        # Simple compliance logic - this would be enhanced per baseline
        if expected_value and expected_value.lower() in current_value.lower():
            compliance_status = ComplianceStatus.COMPLIANT
            gap_description = None
            risk_level = "low"
        else:
            compliance_status = ComplianceStatus.NON_COMPLIANT
            gap_description = f"Expected '{expected_value}' but found '{current_value[:100]}...'"
            risk_level = baseline.criticality_level.value

        return ComplianceResult(
            baseline_id=baseline.baseline_id,
            service_name=baseline.service_name,
            compliance_status=compliance_status,
            confidence_level="medium",
            current_value=current_value[:500],  # Limit size
            expected_value=expected_value,
            gap_description=gap_description,
            risk_level=risk_level,
            evidence_data={
                "gam_output": current_value[:1000],
                "command": baseline.gam_command
            },
            check_method="gam_command",
            assessment_date=datetime.now()
        )

    def _create_error_result(self, baseline: ScubaBaseline, error_message: str) -> ComplianceResult:
        """Create error result for failed checks"""
        return ComplianceResult(
            baseline_id=baseline.baseline_id,
            service_name=baseline.service_name,
            compliance_status=ComplianceStatus.UNABLE_TO_CHECK,
            confidence_level="low",
            current_value=None,
            expected_value=baseline.expected_value,
            gap_description=error_message,
            risk_level="medium",
            evidence_data={"error": error_message},
            check_method="error",
            assessment_date=datetime.now()
        )

    def save_compliance_result(self, result: ComplianceResult) -> None:
        """Save compliance result to database"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("""
                    INSERT INTO scuba_compliance_results (
                        baseline_id, assessment_date, compliance_status, confidence_level,
                        current_value, expected_value, gap_description, risk_level,
                        evidence_data, check_method, session_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    result.baseline_id,
                    result.assessment_date.isoformat(),
                    result.compliance_status.value,
                    result.confidence_level,
                    result.current_value,
                    result.expected_value,
                    result.gap_description,
                    result.risk_level,
                    json.dumps(result.evidence_data),
                    result.check_method,
                    self.session_id
                ))
                conn.commit()
                
        except Exception as e:
            logger.error(f"Failed to save compliance result: {e}")

    def run_full_assessment(self, services: Optional[List[str]] = None) -> Dict[str, Any]:
        """
        Run full compliance assessment for specified services
        
        Args:
            services: List of service names to assess, or None for all enabled services
            
        Returns:
            Assessment summary with results and statistics
        """
        logger.info(f"Starting full SCuBA compliance assessment (Session: {self.session_id})")
        
        # Filter baselines by services if specified
        baselines_to_check = self.baselines
        if services:
            baselines_to_check = [b for b in self.baselines if b.service_name in services]
        
        results = []
        assessment_start = datetime.now()
        
        # Process each baseline
        for baseline in baselines_to_check:
            try:
                result = self.check_baseline_compliance(baseline)
                self.save_compliance_result(result)
                results.append(result)
                
            except Exception as e:
                logger.error(f"Error checking baseline {baseline.baseline_id}: {e}")
                error_result = self._create_error_result(baseline, str(e))
                self.save_compliance_result(error_result)
                results.append(error_result)

        assessment_end = datetime.now()
        duration = (assessment_end - assessment_start).total_seconds()
        
        # Calculate summary statistics
        summary = self._calculate_assessment_summary(results, assessment_start, assessment_end)
        
        # Save assessment history
        self._save_assessment_history(summary, duration)
        
        logger.info(f"SCuBA assessment completed in {duration:.1f}s - {summary['overall_compliance_percentage']:.1f}% compliant")
        
        return summary

    def _calculate_assessment_summary(self, results: List[ComplianceResult], 
                                    start_time: datetime, end_time: datetime) -> Dict[str, Any]:
        """Calculate assessment summary statistics"""
        total_assessed = len(results)
        if total_assessed == 0:
            return {"error": "No baselines assessed"}
        
        # Count by status
        status_counts = {}
        for status in ComplianceStatus:
            status_counts[status.value] = sum(1 for r in results if r.compliance_status == status)
        
        # Count by criticality
        criticality_counts = {"critical": 0, "high": 0, "medium": 0, "low": 0}
        for result in results:
            if result.risk_level in criticality_counts:
                criticality_counts[result.risk_level] += 1
        
        # Calculate compliance percentage (excluding manual reviews and unable to check)
        assessable_results = [r for r in results if r.compliance_status in [ComplianceStatus.COMPLIANT, ComplianceStatus.NON_COMPLIANT]]
        if assessable_results:
            compliant_count = sum(1 for r in assessable_results if r.compliance_status == ComplianceStatus.COMPLIANT)
            compliance_percentage = (compliant_count / len(assessable_results)) * 100
        else:
            compliance_percentage = 0.0
        
        return {
            "assessment_id": self.session_id,
            "assessment_start": start_time.isoformat(),
            "assessment_end": end_time.isoformat(),
            "total_baselines_assessed": total_assessed,
            "overall_compliance_percentage": round(compliance_percentage, 1),
            "status_breakdown": status_counts,
            "criticality_breakdown": criticality_counts,
            "services_assessed": list(set(r.service_name for r in results)),
            "critical_findings": status_counts.get("non_compliant", 0),
            "manual_review_items": status_counts.get("manual_review", 0)
        }

    def _save_assessment_history(self, summary: Dict[str, Any], duration: float) -> None:
        """Save assessment summary to database"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("""
                    INSERT INTO scuba_assessment_history (
                        assessment_id, assessment_name, assessment_type, services_assessed,
                        baselines_assessed, overall_compliance_percentage, critical_findings,
                        high_findings, medium_findings, low_findings, assessment_duration_seconds,
                        started_by, session_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    summary["assessment_id"],
                    f"SCuBA Assessment {datetime.now().strftime('%Y-%m-%d %H:%M')}",
                    "full",
                    json.dumps(summary["services_assessed"]),
                    summary["total_baselines_assessed"],
                    summary["overall_compliance_percentage"],
                    summary["criticality_breakdown"].get("critical", 0),
                    summary["criticality_breakdown"].get("high", 0),
                    summary["criticality_breakdown"].get("medium", 0),
                    summary["criticality_breakdown"].get("low", 0),
                    duration,
                    "python_module",
                    self.session_id
                ))
                conn.commit()
                
        except Exception as e:
            logger.error(f"Failed to save assessment history: {e}")

def main():
    """Command-line interface for SCuBA compliance module"""
    import argparse
    
    parser = argparse.ArgumentParser(description="GWOMBAT SCuBA Compliance Assessment")
    parser.add_argument("--db-path", default="./config/gwombat.db", help="Path to GWOMBAT database")
    parser.add_argument("--gam-path", default="gam", help="Path to GAM executable")
    parser.add_argument("--services", nargs="*", help="Services to assess (default: all enabled)")
    parser.add_argument("--output", choices=["json", "table"], default="table", help="Output format")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Initialize compliance engine
    scuba = ScubaCompliance(args.db_path, args.gam_path)
    
    # Run assessment
    results = scuba.run_full_assessment(args.services)
    
    # Output results
    if args.output == "json":
        print(json.dumps(results, indent=2))
    else:
        # Table output
        print("\n🔐 SCuBA Compliance Assessment Results")
        print("=" * 50)
        print(f"Assessment ID: {results['assessment_id']}")
        print(f"Overall Compliance: {results['overall_compliance_percentage']:.1f}%")
        print(f"Baselines Assessed: {results['total_baselines_assessed']}")
        print(f"Services: {', '.join(results['services_assessed'])}")
        print(f"Critical Findings: {results['critical_findings']}")
        print(f"Manual Review Items: {results['manual_review_items']}")

if __name__ == "__main__":
    main()