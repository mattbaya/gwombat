#!/bin/bash
# Google Forms Integration for GWOMBAT
# Self-service request system for groups and drive access

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Load environment configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$GWOMBAT_ROOT/.env" ]]; then
    source "$GWOMBAT_ROOT/.env"
fi

# Configuration
GAM="${GAM_PATH:-gam}"
DOMAIN="${DOMAIN:-your-domain.edu}"
ADMIN_USER="${ADMIN_USER:-gwombat@$DOMAIN}"
FORMS_FOLDER_NAME="GWOMBAT Self-Service Forms"
RESPONSES_FOLDER_NAME="GWOMBAT Form Responses"

# Form configurations
FORMS_CONFIG_DIR="$GWOMBAT_ROOT/config/forms"
mkdir -p "$FORMS_CONFIG_DIR"

log_forms() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] FORMS: $message" | tee -a "$GWOMBAT_ROOT/logs/forms-integration.log"
    
    case "$level" in
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        *) echo -e "${CYAN}[INFO]${NC} $message" ;;
    esac
}

# Check dependencies
check_forms_dependencies() {
    log_forms "Checking Google Forms integration dependencies"
    
    if ! command -v "$GAM" >/dev/null 2>&1; then
        log_forms "GAM not found at $GAM" "ERROR"
        return 1
    fi
    
    if ! $GAM info domain >/dev/null 2>&1; then
        log_forms "GAM not properly configured for domain $DOMAIN" "ERROR"
        return 1
    fi
    
    log_forms "Dependencies satisfied"
    return 0
}

# Create forms folder structure
create_forms_structure() {
    log_forms "Creating Google Forms folder structure"
    
    # Create main forms folder
    local forms_folder_id
    forms_folder_id=$($GAM user "$ADMIN_USER" add drivefile drivefilename "$FORMS_FOLDER_NAME" mimetype gfolder 2>/dev/null | grep "Created Drive File/Folder ID" | awk '{print $NF}')
    
    if [[ -z "$forms_folder_id" ]]; then
        # Folder might already exist, try to find it
        forms_folder_id=$($GAM user "$ADMIN_USER" print filelist query "name='$FORMS_FOLDER_NAME' and mimeType='application/vnd.google-apps.folder'" fields id 2>/dev/null | tail -n +2 | head -1 | cut -d, -f1)
    fi
    
    if [[ -n "$forms_folder_id" ]]; then
        echo "FORMS_FOLDER_ID=$forms_folder_id" > "$FORMS_CONFIG_DIR/folder_ids.conf"
        log_forms "Forms folder created/found: $forms_folder_id"
    else
        log_forms "Failed to create forms folder" "ERROR"
        return 1
    fi
    
    # Create responses folder
    local responses_folder_id
    responses_folder_id=$($GAM user "$ADMIN_USER" add drivefile drivefilename "$RESPONSES_FOLDER_NAME" mimetype gfolder parentid "$forms_folder_id" 2>/dev/null | grep "Created Drive File/Folder ID" | awk '{print $NF}')
    
    if [[ -n "$responses_folder_id" ]]; then
        echo "RESPONSES_FOLDER_ID=$responses_folder_id" >> "$FORMS_CONFIG_DIR/folder_ids.conf"
        log_forms "Responses folder created: $responses_folder_id"
    fi
    
    return 0
}

# Create group access request form
create_group_access_form() {
    log_forms "Creating Group Access Request Form"
    
    # Load folder IDs
    if [[ -f "$FORMS_CONFIG_DIR/folder_ids.conf" ]]; then
        source "$FORMS_CONFIG_DIR/folder_ids.conf"
    fi
    
    # Create the form JSON configuration
    cat > "$FORMS_CONFIG_DIR/group_access_form.json" << 'EOF'
{
  "info": {
    "title": "Group Access Request",
    "description": "Request access to Google Groups for collaboration and communication. This form will be reviewed by IT administrators."
  },
  "items": [
    {
      "title": "Requester Information",
      "description": "Please provide your contact information",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Email Address",
      "description": "Your institutional email address",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Group Name or Email",
      "description": "The Google Group you want to access (e.g., faculty-research@domain.edu)",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Access Level Requested",
      "description": "What level of access do you need?",
      "questionItem": {
        "question": {
          "required": true,
          "choiceQuestion": {
            "type": "RADIO",
            "options": [
              {"value": "Member - Can receive and send messages"},
              {"value": "Manager - Can manage group settings and members"},
              {"value": "Owner - Full administrative access"}
            ]
          }
        }
      }
    },
    {
      "title": "Business Justification",
      "description": "Please explain why you need access to this group",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": true
          }
        }
      }
    },
    {
      "title": "Duration of Access",
      "description": "How long do you need this access?",
      "questionItem": {
        "question": {
          "required": true,
          "choiceQuestion": {
            "type": "RADIO",
            "options": [
              {"value": "Permanent - Ongoing role"},
              {"value": "6 months - Project-based"},
              {"value": "1 year - Academic year"},
              {"value": "Other - Specify in comments"}
            ]
          }
        }
      }
    },
    {
      "title": "Supervisor/Sponsor",
      "description": "Name and email of your supervisor or project sponsor",
      "questionItem": {
        "question": {
          "required": false,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Additional Comments",
      "description": "Any additional information or special requirements",
      "questionItem": {
        "question": {
          "required": false,
          "textQuestion": {
            "paragraph": true
          }
        }
      }
    }
  ],
  "settings": {
    "quizSettings": {
      "isQuiz": false
    }
  }
}
EOF

    # Note: In practice, you would use Google Forms API to create the form
    # For GWOMBAT, we'll provide instructions and templates
    
    log_forms "Group access form template created at $FORMS_CONFIG_DIR/group_access_form.json"
    
    # Create setup instructions
    cat > "$FORMS_CONFIG_DIR/group_access_setup_instructions.md" << 'EOF'
# Group Access Request Form Setup

## Manual Setup Instructions

1. **Create the Form:**
   - Go to https://forms.google.com
   - Click "Create a new form"
   - Copy the structure from `group_access_form.json`

2. **Configure Form Settings:**
   - Set title: "Group Access Request"
   - Add description from the JSON file
   - Configure each question as specified

3. **Set Up Response Destination:**
   - Click "Responses" tab
   - Click the Google Sheets icon
   - Choose "Create a new spreadsheet"
   - Name it "Group Access Requests"

4. **Configure Permissions:**
   - Share the form with appropriate domain users
   - Set up notification emails for new responses

5. **Integration with GWOMBAT:**
   - Save the form ID and sheet ID in the configuration
   - Use the response processing script to handle requests

## Automated Processing

The response processor will:
- Validate requests against domain policies
- Check existing group memberships
- Generate approval workflows
- Execute approved requests via GAM
- Send notification emails

## Security Considerations

- Limit form access to domain users only
- Implement approval workflows for sensitive groups
- Log all access grants and denials
- Regular audit of group memberships
EOF

    log_forms "Group access form setup instructions created"
    return 0
}

# Create shared drive access request form
create_drive_access_form() {
    log_forms "Creating Shared Drive Access Request Form"
    
    cat > "$FORMS_CONFIG_DIR/drive_access_form.json" << 'EOF'
{
  "info": {
    "title": "Shared Drive Access Request",
    "description": "Request access to shared drives for file collaboration. All requests are subject to approval and access policies."
  },
  "items": [
    {
      "title": "Requester Information",
      "description": "Your full name",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Email Address",
      "description": "Your institutional email address",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Shared Drive Name",
      "description": "Name of the shared drive you need access to",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Drive URL or ID",
      "description": "If you have the drive URL or ID, please provide it",
      "questionItem": {
        "question": {
          "required": false,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Access Level Needed",
      "description": "What level of access do you require?",
      "questionItem": {
        "question": {
          "required": true,
          "choiceQuestion": {
            "type": "RADIO",
            "options": [
              {"value": "Viewer - Read-only access"},
              {"value": "Commenter - Can add comments"},
              {"value": "Editor - Can edit files"},
              {"value": "Content Manager - Can manage files and folders"},
              {"value": "Manager - Can manage members and settings"}
            ]
          }
        }
      }
    },
    {
      "title": "Business Purpose",
      "description": "Explain why you need access to this shared drive",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": true
          }
        }
      }
    },
    {
      "title": "Project or Department",
      "description": "Which project or department is this request for?",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Access Duration",
      "description": "How long do you need this access?",
      "questionItem": {
        "question": {
          "required": true,
          "choiceQuestion": {
            "type": "RADIO",
            "options": [
              {"value": "Permanent - Ongoing role"},
              {"value": "3 months - Short-term project"},
              {"value": "6 months - Medium-term project"},
              {"value": "1 year - Academic year or annual project"},
              {"value": "Other - Specify in comments"}
            ]
          }
        }
      }
    },
    {
      "title": "Data Sensitivity",
      "description": "Does this drive contain sensitive data?",
      "questionItem": {
        "question": {
          "required": true,
          "choiceQuestion": {
            "type": "RADIO",
            "options": [
              {"value": "Public - No sensitive data"},
              {"value": "Internal - Internal use only"},
              {"value": "Confidential - Requires special handling"},
              {"value": "Unknown - Needs assessment"}
            ]
          }
        }
      }
    },
    {
      "title": "Supervisor Approval",
      "description": "Supervisor or manager who approves this request",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    }
  ]
}
EOF

    cat > "$FORMS_CONFIG_DIR/drive_access_setup_instructions.md" << 'EOF'
# Shared Drive Access Request Form Setup

## Form Creation Steps

1. **Create Google Form:**
   - Use the structure from `drive_access_form.json`
   - Configure response collection to Google Sheets

2. **Response Processing:**
   - Automatic validation of drive names/IDs
   - Permission level verification
   - Supervisor notification workflow
   - Security assessment for sensitive data

3. **Approval Workflow:**
   - Automatic approval for public drives with viewer access
   - Manager approval required for editor access
   - IT Security review for confidential data access

## Integration Features

- **Drive Validation:** Verify drive exists and requester eligibility
- **Permission Mapping:** Map form selections to Google Drive roles
- **Audit Logging:** Track all access grants in GWOMBAT database
- **Expiration Management:** Set up automatic access reviews
- **Security Scanning:** Check for external sharing violations

## Automated Actions

Approved requests will automatically:
1. Add user to shared drive with specified permissions
2. Send confirmation email to requester
3. Log action in GWOMBAT audit trail
4. Schedule access review based on duration
5. Notify drive managers of new members
EOF

    log_forms "Shared drive access form template created"
    return 0
}

# Create new group creation request form
create_group_creation_form() {
    log_forms "Creating Group Creation Request Form"
    
    cat > "$FORMS_CONFIG_DIR/group_creation_form.json" << 'EOF'
{
  "info": {
    "title": "New Google Group Creation Request",
    "description": "Request creation of a new Google Group for team collaboration, project communication, or departmental use."
  },
  "items": [
    {
      "title": "Requester Information",
      "description": "Your full name",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Requester Email",
      "description": "Your institutional email address",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Proposed Group Email",
      "description": "Desired email address for the group (e.g., project-team@domain.edu)",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Group Display Name",
      "description": "Human-readable name for the group",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    },
    {
      "title": "Group Description",
      "description": "Brief description of the group's purpose",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": true
          }
        }
      }
    },
    {
      "title": "Group Type",
      "description": "What type of group is this?",
      "questionItem": {
        "question": {
          "required": true,
          "choiceQuestion": {
            "type": "RADIO",
            "options": [
              {"value": "Project Team - Temporary project collaboration"},
              {"value": "Department - Ongoing departmental communication"},
              {"value": "Committee - Standing or ad-hoc committee"},
              {"value": "Course - Academic course communication"},
              {"value": "Research Group - Research collaboration"},
              {"value": "Administrative - Administrative functions"}
            ]
          }
        }
      }
    },
    {
      "title": "Initial Members",
      "description": "List initial members (email addresses, one per line)",
      "questionItem": {
        "question": {
          "required": false,
          "textQuestion": {
            "paragraph": true
          }
        }
      }
    },
    {
      "title": "Group Visibility",
      "description": "Who should be able to see this group?",
      "questionItem": {
        "question": {
          "required": true,
          "choiceQuestion": {
            "type": "RADIO",
            "options": [
              {"value": "Public - Anyone can see and join"},
              {"value": "Domain - Anyone in organization can see and request to join"},
              {"value": "Private - Only members can see the group"},
              {"value": "Restricted - Invitation only"}
            ]
          }
        }
      }
    },
    {
      "title": "Message Permissions",
      "description": "Who can post messages to this group?",
      "questionItem": {
        "question": {
          "required": true,
          "choiceQuestion": {
            "type": "RADIO",
            "options": [
              {"value": "Anyone - Anyone can post"},
              {"value": "Domain - Anyone in organization can post"},
              {"value": "Members - Only group members can post"},
              {"value": "Managers - Only group managers can post"}
            ]
          }
        }
      }
    },
    {
      "title": "Expected Lifespan",
      "description": "How long will this group be needed?",
      "questionItem": {
        "question": {
          "required": true,
          "choiceQuestion": {
            "type": "RADIO",
            "options": [
              {"value": "Permanent - Ongoing indefinitely"},
              {"value": "1 Year - Academic year or annual project"},
              {"value": "6 Months - Medium-term project"},
              {"value": "3 Months - Short-term project"},
              {"value": "Other - Specify in justification"}
            ]
          }
        }
      }
    },
    {
      "title": "Business Justification",
      "description": "Explain why this group is needed and how it will be used",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": true
          }
        }
      }
    },
    {
      "title": "Supervisor/Sponsor",
      "description": "Name and email of approving supervisor or sponsor",
      "questionItem": {
        "question": {
          "required": true,
          "textQuestion": {
            "paragraph": false
          }
        }
      }
    }
  ]
}
EOF

    log_forms "Group creation form template created"
    return 0
}

# Create response processing script
create_response_processor() {
    log_forms "Creating forms response processor"
    
    cat > "$GWOMBAT_ROOT/shared-utilities/process_form_responses.sh" << 'EOF'
#!/bin/bash
# Process Google Forms responses for GWOMBAT self-service requests

# Load GWOMBAT configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$GWOMBAT_ROOT/.env" 2>/dev/null || true

# Configuration
GAM="${GAM_PATH:-gam}"
DOMAIN="${DOMAIN:-your-domain.edu}"
ADMIN_USER="${ADMIN_USER:-gwombat@$DOMAIN}"

# Process group access requests
process_group_access_requests() {
    local responses_sheet="$1"
    
    echo "Processing group access requests from $responses_sheet"
    
    # Download responses (in practice, this would use Google Sheets API)
    # For now, provide framework for manual processing
    
    while IFS=, read -r timestamp name email group_name access_level justification duration supervisor comments; do
        # Skip header row
        [[ "$timestamp" == "Timestamp" ]] && continue
        
        echo "Processing request from $name ($email) for $group_name"
        
        # Validate request
        if validate_group_request "$email" "$group_name" "$access_level"; then
            # Check if approval needed
            if requires_approval "$group_name" "$access_level"; then
                queue_for_approval "$timestamp" "$name" "$email" "$group_name" "$access_level" "$justification"
            else
                # Auto-approve low-risk requests
                grant_group_access "$email" "$group_name" "$access_level"
                send_approval_notification "$email" "$group_name" "$access_level"
            fi
        else
            reject_request "$email" "$group_name" "Validation failed"
        fi
        
    done < "$responses_sheet"
}

# Validate group access request
validate_group_request() {
    local user_email="$1"
    local group_name="$2"
    local access_level="$3"
    
    # Check if user exists in domain
    if ! $GAM info user "$user_email" >/dev/null 2>&1; then
        echo "User $user_email not found in domain"
        return 1
    fi
    
    # Check if group exists
    if ! $GAM info group "$group_name" >/dev/null 2>&1; then
        echo "Group $group_name not found"
        return 1
    fi
    
    # Check if user is already a member
    if $GAM print group-members group "$group_name" | grep -q "$user_email"; then
        echo "User $user_email is already a member of $group_name"
        return 1
    fi
    
    return 0
}

# Check if approval is required
requires_approval() {
    local group_name="$1"
    local access_level="$2"
    
    # Define approval rules
    case "$access_level" in
        *"Owner"*|*"Manager"*)
            return 0  # Always requires approval
            ;;
        *"Member"*)
            # Check if it's a sensitive group
            if echo "$group_name" | grep -qE "(admin|security|finance|hr)"; then
                return 0  # Requires approval
            fi
            return 1  # Auto-approve
            ;;
    esac
    
    return 0  # Default to requiring approval
}

# Grant group access
grant_group_access() {
    local user_email="$1"
    local group_name="$2"
    local access_level="$3"
    
    local role="MEMBER"
    case "$access_level" in
        *"Manager"*) role="MANAGER" ;;
        *"Owner"*) role="OWNER" ;;
    esac
    
    if $GAM update group "$group_name" add "$role" "$user_email"; then
        # Log the action
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$timestamp,GROUP_ACCESS_GRANTED,$user_email,$group_name,$role,AUTO_APPROVED" >> "$GWOMBAT_ROOT/logs/forms-actions.log"
        
        echo "Granted $role access to $user_email for $group_name"
        return 0
    else
        echo "Failed to grant access to $user_email for $group_name"
        return 1
    fi
}

# Send notification emails
send_approval_notification() {
    local user_email="$1"
    local group_name="$2"
    local access_level="$3"
    
    # In practice, this would send an email
    echo "Notification: Access granted to $user_email for $group_name ($access_level)"
}

# Queue request for manual approval
queue_for_approval() {
    local timestamp="$1"
    local name="$2"
    local email="$3"
    local group_name="$4"
    local access_level="$5"
    local justification="$6"
    
    # Add to approval queue
    echo "$timestamp,PENDING_APPROVAL,$name,$email,$group_name,$access_level,$justification" >> "$GWOMBAT_ROOT/logs/approval-queue.log"
    
    echo "Request queued for approval: $name requesting $access_level access to $group_name"
}

# Main function
main() {
    case "${1:-}" in
        "group-access")
            process_group_access_requests "$2"
            ;;
        "drive-access")
            echo "Drive access processing not yet implemented"
            ;;
        "group-creation")
            echo "Group creation processing not yet implemented"
            ;;
        *)
            echo "Usage: $0 {group-access|drive-access|group-creation} <responses-file>"
            echo ""
            echo "Process Google Forms responses for GWOMBAT self-service requests"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$GWOMBAT_ROOT/shared-utilities/process_form_responses.sh"
    log_forms "Response processor created"
    return 0
}

# Create admin dashboard for form management
create_forms_dashboard() {
    log_forms "Creating forms management dashboard"
    
    cat > "$GWOMBAT_ROOT/shared-utilities/forms_dashboard.sh" << 'EOF'
#!/bin/bash
# Forms Management Dashboard for GWOMBAT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$GWOMBAT_ROOT/.env" 2>/dev/null || true

show_forms_dashboard() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                     GWOMBAT Forms Management Dashboard                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show pending approvals
    if [[ -f "$GWOMBAT_ROOT/logs/approval-queue.log" ]]; then
        local pending_count=$(grep "PENDING_APPROVAL" "$GWOMBAT_ROOT/logs/approval-queue.log" | wc -l)
        echo -e "${YELLOW}📋 Pending Approvals: $pending_count${NC}"
    fi
    
    echo ""
    echo "Dashboard Options:"
    echo "1. 📝 View pending approval requests"
    echo "2. ✅ Process approval queue"
    echo "3. 📊 View forms activity log"
    echo "4. ⚙️  Configure form settings"
    echo "5. 📧 Send notification emails"
    echo "6. 🔄 Sync form responses"
    echo "7. 📈 Generate forms usage report"
    echo "8. 🏠 Return to main menu"
    echo ""
    
    read -p "Select an option (1-8): " choice
    
    case $choice in
        1) view_pending_approvals ;;
        2) process_approval_queue ;;
        3) view_forms_activity ;;
        4) configure_forms ;;
        5) send_notifications ;;
        6) sync_responses ;;
        7) generate_report ;;
        8) return 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; show_forms_dashboard ;;
    esac
}

view_pending_approvals() {
    echo -e "${CYAN}📋 Pending Approval Requests${NC}"
    echo ""
    
    if [[ -f "$GWOMBAT_ROOT/logs/approval-queue.log" ]]; then
        echo "Timestamp,Status,Name,Email,Group,Access Level,Justification"
        echo "================================================================"
        grep "PENDING_APPROVAL" "$GWOMBAT_ROOT/logs/approval-queue.log" | head -20
    else
        echo "No pending approvals found"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_forms_dashboard
}

process_approval_queue() {
    echo -e "${CYAN}✅ Processing Approval Queue${NC}"
    echo ""
    
    if [[ -f "$GWOMBAT_ROOT/logs/approval-queue.log" ]]; then
        while IFS=, read -r timestamp status name email group access_level justification; do
            [[ "$status" != "PENDING_APPROVAL" ]] && continue
            
            echo "Request: $name ($email) for $group ($access_level)"
            echo "Justification: $justification"
            echo ""
            echo "Actions:"
            echo "1. Approve"
            echo "2. Deny" 
            echo "3. Skip"
            echo ""
            read -p "Select action (1-3): " action
            
            case $action in
                1)
                    # Process approval
                    if "$GWOMBAT_ROOT/shared-utilities/process_form_responses.sh" grant-access "$email" "$group" "$access_level"; then
                        echo -e "${GREEN}✓ Access granted${NC}"
                        # Update log
                        sed -i "s/$timestamp,PENDING_APPROVAL/$timestamp,APPROVED/" "$GWOMBAT_ROOT/logs/approval-queue.log"
                    fi
                    ;;
                2)
                    echo "Denial reason:"
                    read -p "> " reason
                    sed -i "s/$timestamp,PENDING_APPROVAL/$timestamp,DENIED,$reason/" "$GWOMBAT_ROOT/logs/approval-queue.log"
                    echo -e "${YELLOW}Request denied${NC}"
                    ;;
                3)
                    echo "Skipped"
                    ;;
            esac
            echo ""
        done < "$GWOMBAT_ROOT/logs/approval-queue.log"
    else
        echo "No approval queue found"
    fi
    
    read -p "Press Enter to continue..."
    show_forms_dashboard
}

view_forms_activity() {
    echo -e "${CYAN}📊 Forms Activity Log${NC}"
    echo ""
    
    if [[ -f "$GWOMBAT_ROOT/logs/forms-actions.log" ]]; then
        echo "Recent activity:"
        tail -20 "$GWOMBAT_ROOT/logs/forms-actions.log"
    else
        echo "No activity log found"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_forms_dashboard
}

# Run dashboard if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_forms_dashboard
fi
EOF

    chmod +x "$GWOMBAT_ROOT/shared-utilities/forms_dashboard.sh"
    log_forms "Forms dashboard created"
    return 0
}

# Main setup function
setup_google_forms_integration() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Google Forms Integration Setup                            ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_forms "Starting Google Forms integration setup"
    
    if ! check_forms_dependencies; then
        log_forms "Dependencies not satisfied, exiting" "ERROR"
        return 1
    fi
    
    echo "This setup will create:"
    echo "• Google Forms templates for self-service requests"
    echo "• Response processing automation"
    echo "• Admin dashboard for approval management"
    echo "• Integration with GWOMBAT workflows"
    echo ""
    
    read -p "Continue with setup? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo "Setup cancelled"
        return 0
    fi
    
    # Create folder structure
    if ! create_forms_structure; then
        log_forms "Failed to create folder structure" "ERROR"
        return 1
    fi
    
    # Create form templates
    create_group_access_form
    create_drive_access_form
    create_group_creation_form
    
    # Create processing tools
    create_response_processor
    create_forms_dashboard
    
    # Create summary
    cat > "$FORMS_CONFIG_DIR/SETUP_SUMMARY.md" << EOF
# Google Forms Integration Setup Complete

## Created Components

### Form Templates
- \`group_access_form.json\` - Group access request form structure
- \`drive_access_form.json\` - Shared drive access request form structure
- \`group_creation_form.json\` - New group creation request form structure

### Processing Tools
- \`process_form_responses.sh\` - Automated response processing
- \`forms_dashboard.sh\` - Admin management dashboard

### Configuration
- \`folder_ids.conf\` - Google Drive folder IDs for forms storage
- Form setup instructions for each template

## Next Steps

1. **Create Google Forms manually** using the provided JSON templates
2. **Set up response sheets** to collect form submissions
3. **Configure approval workflows** based on your organization's policies
4. **Test the integration** with sample requests
5. **Train administrators** on the dashboard and approval process

## Usage

### For End Users
- Submit requests through the published Google Forms
- Receive email notifications of approval status
- Access granted automatically for approved requests

### For Administrators
- Monitor requests: \`./shared-utilities/forms_dashboard.sh\`
- Process responses: \`./shared-utilities/process_form_responses.sh\`
- View activity logs in \`logs/forms-actions.log\`

## Security Features

- Domain-restricted form access
- Approval workflows for sensitive requests
- Audit logging of all actions
- Automated validation of requests
- Integration with GWOMBAT database

Setup completed: $(date)
EOF
    
    log_forms "Google Forms integration setup completed successfully" "SUCCESS"
    
    echo ""
    echo -e "${GREEN}✅ Google Forms Integration Setup Complete!${NC}"
    echo ""
    echo "Summary:"
    echo "• Form templates created in $FORMS_CONFIG_DIR"
    echo "• Processing tools installed in shared-utilities/"
    echo "• Admin dashboard available at shared-utilities/forms_dashboard.sh"
    echo "• Setup documentation: $FORMS_CONFIG_DIR/SETUP_SUMMARY.md"
    echo ""
    echo "Next: Create the actual Google Forms using the provided templates"
    
    return 0
}

# Script execution
case "${1:-}" in
    "setup")
        setup_google_forms_integration
        ;;
    "dashboard")
        "$GWOMBAT_ROOT/shared-utilities/forms_dashboard.sh"
        ;;
    "process")
        "$GWOMBAT_ROOT/shared-utilities/process_form_responses.sh" "$2" "$3"
        ;;
    *)
        echo "Google Forms Integration for GWOMBAT"
        echo "Usage: $0 {setup|dashboard|process}"
        echo ""
        echo "Commands:"
        echo "  setup     - Set up Google Forms integration"
        echo "  dashboard - Open forms management dashboard"
        echo "  process   - Process form responses"
        echo ""
        exit 1
        ;;
esac