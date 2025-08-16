#!/usr/bin/env python3
"""
Google Workspace API Integration for GWOMBAT
Enhanced API capabilities for compliance checking and advanced reporting

This module provides Python-based Google Workspace API integration to complement
GAM commands with direct API access for more sophisticated compliance checking.
"""

import json
import logging
import sqlite3
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Union
from pathlib import Path
from dataclasses import dataclass
import os

# Google API imports (optional - graceful degradation if not available)
try:
    from googleapiclient.discovery import build
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.errors import HttpError
    GOOGLE_API_AVAILABLE = True
except ImportError:
    GOOGLE_API_AVAILABLE = False
    logging.warning("Google API client libraries not available - API features will be disabled")

logger = logging.getLogger(__name__)

@dataclass
class APIServiceConfig:
    """Configuration for Google Workspace API services"""
    service_name: str
    version: str
    scopes: List[str]
    enabled: bool = True

class GoogleWorkspaceAPI:
    """
    Enhanced Google Workspace API integration for GWOMBAT
    
    Provides direct API access for compliance checking and advanced reporting
    capabilities that complement GAM-based operations.
    """
    
    # Standard Google Workspace API scopes for compliance checking
    SCOPES = [
        'https://www.googleapis.com/auth/admin.directory.user.readonly',
        'https://www.googleapis.com/auth/admin.directory.group.readonly',
        'https://www.googleapis.com/auth/admin.directory.orgunit.readonly',
        'https://www.googleapis.com/auth/admin.directory.domain.readonly',
        'https://www.googleapis.com/auth/admin.reports.audit.readonly',
        'https://www.googleapis.com/auth/admin.reports.usage.readonly',
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/gmail.settings.basic',
        'https://www.googleapis.com/auth/calendar.readonly'
    ]
    
    def __init__(self, db_path: str = "./config/gwombat.db", 
                 credentials_path: str = "./config/gws_credentials.json",
                 token_path: str = "./config/gws_token.json"):
        """
        Initialize Google Workspace API integration
        
        Args:
            db_path: Path to GWOMBAT database
            credentials_path: Path to Google OAuth2 credentials file
            token_path: Path to store/load OAuth2 tokens
        """
        self.db_path = Path(db_path)
        self.credentials_path = Path(credentials_path)
        self.token_path = Path(token_path)
        self.session_id = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_gws_api_{id(self)}"
        
        # API service configurations
        self.api_services = {
            'admin': APIServiceConfig('admin', 'directory_v1', self.SCOPES[:4]),
            'reports': APIServiceConfig('admin', 'reports_v1', self.SCOPES[4:6]),
            'drive': APIServiceConfig('drive', 'v3', [self.SCOPES[6]]),
            'gmail': APIServiceConfig('gmail', 'v1', [self.SCOPES[7]]),
            'calendar': APIServiceConfig('calendar', 'v3', [self.SCOPES[8]])
        }
        
        # Initialize services
        self.services = {}
        self.authenticated = False
        
        if GOOGLE_API_AVAILABLE:
            self._authenticate()
        else:
            logger.warning("Google API client not available - using GAM fallback mode")

    def _authenticate(self) -> bool:
        """Authenticate with Google Workspace APIs"""
        try:
            creds = None
            
            # Load existing token
            if self.token_path.exists():
                creds = Credentials.from_authorized_user_file(str(self.token_path), self.SCOPES)
            
            # If no valid credentials, authenticate
            if not creds or not creds.valid:
                if creds and creds.expired and creds.refresh_token:
                    creds.refresh(Request())
                else:
                    if not self.credentials_path.exists():
                        logger.warning(f"Credentials file not found at {self.credentials_path}")
                        logger.info("To enable API features, download OAuth2 credentials from Google Cloud Console")
                        return False
                    
                    flow = InstalledAppFlow.from_client_secrets_file(
                        str(self.credentials_path), self.SCOPES)
                    creds = flow.run_local_server(port=0)
                
                # Save credentials
                self.token_path.parent.mkdir(parents=True, exist_ok=True)
                with open(self.token_path, 'w') as token:
                    token.write(creds.to_json())
            
            # Build API services
            self.services['admin'] = build('admin', 'directory_v1', credentials=creds)
            self.services['reports'] = build('admin', 'reports_v1', credentials=creds)
            self.services['drive'] = build('drive', 'v3', credentials=creds)
            self.services['gmail'] = build('gmail', 'v1', credentials=creds)
            self.services['calendar'] = build('calendar', 'v3', credentials=creds)
            
            self.authenticated = True
            logger.info("Google Workspace API authentication successful")
            return True
            
        except Exception as e:
            logger.error(f"API authentication failed: {e}")
            logger.info("Falling back to GAM-only mode")
            return False

    def is_authenticated(self) -> bool:
        """Check if API authentication is successful"""
        return self.authenticated and GOOGLE_API_AVAILABLE

    def get_domain_info(self) -> Optional[Dict[str, Any]]:
        """Get domain configuration information"""
        if not self.is_authenticated():
            return None
        
        try:
            service = self.services['admin']
            domains = service.domains().list(customer='my_customer').execute()
            
            return {
                'domains': domains.get('domains', []),
                'primary_domain': next((d['domainName'] for d in domains.get('domains', []) 
                                      if d.get('isPrimary')), None),
                'verified_domains': [d['domainName'] for d in domains.get('domains', []) 
                                   if d.get('verified')],
                'retrieved_at': datetime.now().isoformat()
            }
            
        except HttpError as e:
            logger.error(f"Error retrieving domain info: {e}")
            return None

    def get_org_unit_structure(self) -> Optional[Dict[str, Any]]:
        """Get organizational unit structure"""
        if not self.is_authenticated():
            return None
        
        try:
            service = self.services['admin']
            org_units = service.orgunits().list(customerId='my_customer').execute()
            
            return {
                'organizational_units': org_units.get('organizationUnits', []),
                'retrieved_at': datetime.now().isoformat()
            }
            
        except HttpError as e:
            logger.error(f"Error retrieving org units: {e}")
            return None

    def get_user_security_settings(self, user_email: str) -> Optional[Dict[str, Any]]:
        """Get security settings for a specific user"""
        if not self.is_authenticated():
            return None
        
        try:
            service = self.services['admin']
            user = service.users().get(userKey=user_email).execute()
            
            # Extract security-relevant information
            security_info = {
                'user_email': user_email,
                'suspended': user.get('suspended', False),
                'archived': user.get('archived', False),
                'two_factor_enrolled': user.get('isEnforcedIn2Sv', False),
                'admin_privileges': user.get('isAdmin', False),
                'delegated_admin': user.get('isDelegatedAdmin', False),
                'last_login': user.get('lastLoginTime'),
                'creation_time': user.get('creationTime'),
                'org_unit_path': user.get('orgUnitPath'),
                'retrieved_at': datetime.now().isoformat()
            }
            
            return security_info
            
        except HttpError as e:
            logger.error(f"Error retrieving user security settings for {user_email}: {e}")
            return None

    def get_gmail_settings(self, user_email: str) -> Optional[Dict[str, Any]]:
        """Get Gmail security settings for a user"""
        if not self.is_authenticated():
            return None
        
        try:
            service = self.services['gmail']
            
            # Get various Gmail settings
            settings = {}
            
            # Auto-forwarding settings
            try:
                forwarding = service.users().settings().getAutoForwarding(userId=user_email).execute()
                settings['auto_forwarding'] = forwarding
            except HttpError:
                settings['auto_forwarding'] = None
            
            # IMAP settings
            try:
                imap = service.users().settings().getImap(userId=user_email).execute()
                settings['imap'] = imap
            except HttpError:
                settings['imap'] = None
            
            # POP settings
            try:
                pop = service.users().settings().getPop(userId=user_email).execute()
                settings['pop'] = pop
            except HttpError:
                settings['pop'] = None
            
            # Vacation responder
            try:
                vacation = service.users().settings().getVacation(userId=user_email).execute()
                settings['vacation'] = vacation
            except HttpError:
                settings['vacation'] = None
            
            settings['user_email'] = user_email
            settings['retrieved_at'] = datetime.now().isoformat()
            
            return settings
            
        except HttpError as e:
            logger.error(f"Error retrieving Gmail settings for {user_email}: {e}")
            return None

    def get_drive_sharing_settings(self, user_email: str) -> Optional[Dict[str, Any]]:
        """Get Drive sharing settings and recent sharing activity"""
        if not self.is_authenticated():
            return None
        
        try:
            service = self.services['drive']
            
            # Get user's drive about info
            about = service.about().get(fields='user,storageQuota').execute()
            
            # Get recent files with sharing info (limited for privacy)
            files_result = service.files().list(
                q="visibility='anyoneWithLink' or visibility='anyoneCanFind'",
                pageSize=10,
                fields="files(id,name,shared,sharingUser,permissions)"
            ).execute()
            
            sharing_info = {
                'user_email': user_email,
                'storage_quota': about.get('storageQuota', {}),
                'publicly_shared_files_count': len(files_result.get('files', [])),
                'retrieved_at': datetime.now().isoformat()
            }
            
            return sharing_info
            
        except HttpError as e:
            logger.error(f"Error retrieving Drive sharing settings for {user_email}: {e}")
            return None

    def get_admin_activity_report(self, start_date: datetime, end_date: datetime) -> Optional[List[Dict[str, Any]]]:
        """Get admin activity report for specified date range"""
        if not self.is_authenticated():
            return None
        
        try:
            service = self.services['reports']
            
            activities = service.activities().list(
                userKey='all',
                applicationName='admin',
                startTime=start_date.isoformat() + 'Z',
                endTime=end_date.isoformat() + 'Z'
            ).execute()
            
            return activities.get('items', [])
            
        except HttpError as e:
            logger.error(f"Error retrieving admin activity report: {e}")
            return None

    def get_login_activity_report(self, start_date: datetime, end_date: datetime) -> Optional[List[Dict[str, Any]]]:
        """Get login activity report for specified date range"""
        if not self.is_authenticated():
            return None
        
        try:
            service = self.services['reports']
            
            activities = service.activities().list(
                userKey='all',
                applicationName='login',
                startTime=start_date.isoformat() + 'Z',
                endTime=end_date.isoformat() + 'Z'
            ).execute()
            
            return activities.get('items', [])
            
        except HttpError as e:
            logger.error(f"Error retrieving login activity report: {e}")
            return None

    def check_2sv_enforcement(self) -> Optional[Dict[str, Any]]:
        """Check 2-Step Verification enforcement status"""
        if not self.is_authenticated():
            return None
        
        try:
            service = self.services['admin']
            
            # Get users and check 2SV status
            users_result = service.users().list(
                customer='my_customer',
                maxResults=500,
                fields='users(primaryEmail,isEnforcedIn2Sv,suspended)'
            ).execute()
            
            users = users_result.get('users', [])
            total_users = len([u for u in users if not u.get('suspended', False)])
            enforced_users = len([u for u in users if u.get('isEnforcedIn2Sv', False) and not u.get('suspended', False)])
            
            return {
                'total_active_users': total_users,
                'users_with_2sv_enforced': enforced_users,
                'enforcement_percentage': (enforced_users / total_users * 100) if total_users > 0 else 0,
                'retrieved_at': datetime.now().isoformat()
            }
            
        except HttpError as e:
            logger.error(f"Error checking 2SV enforcement: {e}")
            return None

    def save_api_data(self, data_type: str, data: Dict[str, Any]) -> None:
        """Save API data to database for compliance analysis"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("""
                    INSERT OR REPLACE INTO gws_api_data (
                        data_type, data_content, retrieved_at, session_id
                    ) VALUES (?, ?, ?, ?)
                """, (
                    data_type,
                    json.dumps(data),
                    datetime.now().isoformat(),
                    self.session_id
                ))
                conn.commit()
                
        except Exception as e:
            logger.error(f"Failed to save API data: {e}")

    def get_comprehensive_security_snapshot(self) -> Dict[str, Any]:
        """Get comprehensive security snapshot using API calls"""
        logger.info("Collecting comprehensive security snapshot via API")
        
        snapshot = {
            'collection_time': datetime.now().isoformat(),
            'session_id': self.session_id,
            'api_available': self.is_authenticated()
        }
        
        if not self.is_authenticated():
            snapshot['message'] = "Google Workspace API not available - data collection limited"
            return snapshot
        
        # Collect various security-related data
        try:
            # Domain information
            domain_info = self.get_domain_info()
            if domain_info:
                snapshot['domain_info'] = domain_info
                self.save_api_data('domain_info', domain_info)
            
            # Organizational structure
            org_structure = self.get_org_unit_structure()
            if org_structure:
                snapshot['org_structure'] = org_structure
                self.save_api_data('org_structure', org_structure)
            
            # 2SV enforcement status
            twosv_status = self.check_2sv_enforcement()
            if twosv_status:
                snapshot['2sv_enforcement'] = twosv_status
                self.save_api_data('2sv_enforcement', twosv_status)
            
            # Recent admin activity (last 24 hours)
            end_date = datetime.now()
            start_date = end_date - timedelta(days=1)
            admin_activity = self.get_admin_activity_report(start_date, end_date)
            if admin_activity:
                snapshot['recent_admin_activity'] = {
                    'activity_count': len(admin_activity),
                    'date_range': f"{start_date.isoformat()} to {end_date.isoformat()}"
                }
                self.save_api_data('admin_activity', {'activities': admin_activity})
            
            # Recent login activity (last 24 hours)
            login_activity = self.get_login_activity_report(start_date, end_date)
            if login_activity:
                snapshot['recent_login_activity'] = {
                    'activity_count': len(login_activity),
                    'date_range': f"{start_date.isoformat()} to {end_date.isoformat()}"
                }
                self.save_api_data('login_activity', {'activities': login_activity})
            
            logger.info("Security snapshot collection completed successfully")
            
        except Exception as e:
            logger.error(f"Error collecting security snapshot: {e}")
            snapshot['error'] = str(e)
        
        return snapshot

def main():
    """Command-line interface for Google Workspace API module"""
    import argparse
    
    parser = argparse.ArgumentParser(description="GWOMBAT Google Workspace API Integration")
    parser.add_argument("--db-path", default="./config/gwombat.db", help="Path to GWOMBAT database")
    parser.add_argument("--credentials", default="./config/gws_credentials.json", help="Path to Google OAuth2 credentials")
    parser.add_argument("--action", choices=["test-auth", "security-snapshot", "domain-info"], 
                       default="test-auth", help="Action to perform")
    parser.add_argument("--output", choices=["json", "table"], default="table", help="Output format")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Initialize API integration
    gws_api = GoogleWorkspaceAPI(args.db_path, args.credentials)
    
    # Perform requested action
    if args.action == "test-auth":
        if gws_api.is_authenticated():
            print("✓ Google Workspace API authentication successful")
            domain_info = gws_api.get_domain_info()
            if domain_info:
                print(f"Primary domain: {domain_info['primary_domain']}")
        else:
            print("✗ Google Workspace API authentication failed")
            print("Please ensure credentials file is present and valid")
    
    elif args.action == "security-snapshot":
        snapshot = gws_api.get_comprehensive_security_snapshot()
        if args.output == "json":
            print(json.dumps(snapshot, indent=2))
        else:
            print("\n🔒 Google Workspace Security Snapshot")
            print("=" * 45)
            print(f"Collection Time: {snapshot['collection_time']}")
            print(f"API Available: {snapshot['api_available']}")
            if snapshot.get('domain_info'):
                print(f"Primary Domain: {snapshot['domain_info']['primary_domain']}")
            if snapshot.get('2sv_enforcement'):
                print(f"2SV Enforcement: {snapshot['2sv_enforcement']['enforcement_percentage']:.1f}%")
    
    elif args.action == "domain-info":
        domain_info = gws_api.get_domain_info()
        if domain_info:
            if args.output == "json":
                print(json.dumps(domain_info, indent=2))
            else:
                print("\n🌐 Domain Information")
                print("=" * 25)
                print(f"Primary Domain: {domain_info['primary_domain']}")
                print(f"Verified Domains: {', '.join(domain_info['verified_domains'])}")
        else:
            print("Unable to retrieve domain information")

if __name__ == "__main__":
    main()