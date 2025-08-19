#!/bin/bash

# GWOMBAT Suspension Workflow Manager
# Configurable suspension lifecycle stage management

# Source configuration and database functions
source "$(dirname "$0")/../gwombat.sh" 2>/dev/null || {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/../config/gwombat_config.sh" 2>/dev/null || {
        echo "Error: Cannot load GWOMBAT configuration"
        exit 1
    }
}

# Database file for workflow management
WORKFLOW_DB="${GWOMBAT_DB_PATH:-local-config/gwombat.db}"
WORKFLOW_SCHEMA="suspension_workflow_schema.sql"

# Initialize workflow database
init_workflow_db() {
    local db_file="$1"
    if [[ ! -f "$db_file" ]]; then
        echo "Creating workflow database: $db_file"
        touch "$db_file"
    fi
    
    if [[ -f "$WORKFLOW_SCHEMA" ]]; then
        echo "Initializing workflow schema..."
        sqlite3 "$db_file" < "$WORKFLOW_SCHEMA"
        echo "Workflow database initialized successfully"
    else
        echo "Warning: Workflow schema file not found: $WORKFLOW_SCHEMA"
        return 1
    fi
}

# Show current workflow configuration
show_workflow_status() {
    echo -e "${CYAN}=== Current Suspension Workflow Configuration ===${NC}"
    echo ""
    
    # Show active stages
    local stages=$(sqlite3 "$WORKFLOW_DB" "
        SELECT stage_order, stage_name, stage_description, days_in_stage, ou_path, 
               CASE WHEN requires_approval = 1 THEN 'Yes' ELSE 'No' END as approval,
               color_code, icon
        FROM suspension_stages 
        WHERE is_active = 1 
        ORDER BY stage_order;
    ")
    
    if [[ -n "$stages" ]]; then
        echo -e "${WHITE}Active Stages:${NC}"
        echo "Order | Stage Name | Days | Requires Approval | OU Path"
        echo "------|------------|------|-------------------|----------"
        
        while IFS='|' read -r order name desc days ou approval color icon; do
            local days_display="${days:-'∞'}"
            echo "$order. $icon $name | $days_display | $approval | $ou"
        done <<< "$stages"
    else
        echo -e "${YELLOW}No active stages configured${NC}"
    fi
    
    echo ""
    
    # Show workflow statistics
    local total_accounts=$(sqlite3 "$WORKFLOW_DB" "SELECT COUNT(*) FROM account_current_stage;" 2>/dev/null || echo "0")
    local overdue_accounts=$(sqlite3 "$WORKFLOW_DB" "SELECT COUNT(*) FROM account_current_stage WHERE is_overdue = 1;" 2>/dev/null || echo "0")
    
    echo -e "${WHITE}Workflow Statistics:${NC}"
    echo "• Total accounts in workflow: $total_accounts"
    echo "• Overdue for review: $overdue_accounts"
    echo ""
    
    # Show accounts by stage
    if [[ "$total_accounts" -gt 0 ]]; then
        echo -e "${WHITE}Accounts by Stage:${NC}"
        sqlite3 "$WORKFLOW_DB" "
            SELECT ss.stage_name, COUNT(acs.email) as count,
                   AVG(acs.days_in_stage) as avg_days
            FROM suspension_stages ss
            LEFT JOIN account_current_stage acs ON ss.id = acs.stage_id
            WHERE ss.is_active = 1
            GROUP BY ss.id, ss.stage_name, ss.stage_order
            ORDER BY ss.stage_order;
        " | while IFS='|' read -r stage_name count avg_days; do
            local avg_display=$(echo "$avg_days" | awk '{printf "%.1f", $1}')
            echo "  $stage_name: $count accounts (avg ${avg_display} days)"
        done
    fi
}

# Manage workflow stages
manage_workflow_stages() {
    while true; do
        clear
        echo -e "${GREEN}=== Manage Suspension Workflow Stages ===${NC}"
        echo ""
        
        show_workflow_status
        
        echo ""
        echo -e "${YELLOW}Stage Management Options:${NC}"
        echo "1. Add new stage"
        echo "2. Edit existing stage"
        echo "3. Reorder stages"
        echo "4. Deactivate stage"
        echo "5. Configure stage actions"
        echo "6. Set up stage transitions"
        echo "7. Load workflow template"
        echo "8. Export current workflow"
        echo ""
        echo "9. Return to previous menu"
        echo ""
        
        read -p "Select option (1-9): " choice
        
        case $choice in
            1) add_workflow_stage ;;
            2) edit_workflow_stage ;;
            3) reorder_workflow_stages ;;
            4) deactivate_workflow_stage ;;
            5) configure_stage_actions ;;
            6) configure_stage_transitions ;;
            7) load_workflow_template ;;
            8) export_workflow ;;
            9) return ;;
            *) 
                echo -e "${RED}Invalid option${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Add new workflow stage
add_workflow_stage() {
    echo -e "${CYAN}=== Add New Workflow Stage ===${NC}"
    echo ""
    
    read -p "Stage name: " stage_name
    if [[ -z "$stage_name" ]]; then
        echo -e "${RED}Stage name cannot be empty${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    read -p "Stage description: " stage_desc
    read -p "Stage order (leave empty for last): " stage_order
    read -p "Days in stage (leave empty for indefinite): " days_in_stage
    read -p "OU path: " ou_path
    read -p "Requires approval? (y/n): " requires_approval
    read -p "Color code (hex, e.g., #FF6B6B): " color_code
    read -p "Icon (emoji): " icon
    
    # Determine stage order
    if [[ -z "$stage_order" ]]; then
        stage_order=$(sqlite3 "$WORKFLOW_DB" "SELECT COALESCE(MAX(stage_order), 0) + 1 FROM suspension_stages;")
    fi
    
    # Convert approval to boolean
    local approval_bool=0
    [[ "$requires_approval" =~ ^[Yy] ]] && approval_bool=1
    
    # Set defaults
    [[ -z "$color_code" ]] && color_code="#808080"
    [[ -z "$icon" ]] && icon="📋"
    [[ -z "$days_in_stage" ]] && days_in_stage="NULL" || days_in_stage="$days_in_stage"
    
    # Insert new stage
    local result=$(sqlite3 "$WORKFLOW_DB" "
        INSERT INTO suspension_stages 
        (stage_name, stage_description, stage_order, days_in_stage, ou_path, requires_approval, color_code, icon)
        VALUES ('$stage_name', '$stage_desc', $stage_order, $days_in_stage, '$ou_path', $approval_bool, '$color_code', '$icon');
        SELECT last_insert_rowid();
    " 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Stage '$stage_name' added successfully (ID: $result)${NC}"
    else
        echo -e "${RED}Error adding stage: $result${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Edit existing workflow stage
edit_workflow_stage() {
    echo -e "${CYAN}=== Edit Workflow Stage ===${NC}"
    echo ""
    
    # Show current stages
    sqlite3 "$WORKFLOW_DB" "
        SELECT id, stage_order, stage_name, days_in_stage, requires_approval
        FROM suspension_stages 
        WHERE is_active = 1 
        ORDER BY stage_order;
    " | while IFS='|' read -r id order name days approval; do
        local days_display="${days:-'∞'}"
        local approval_display=$([ "$approval" = "1" ] && echo "Yes" || echo "No")
        echo "$id. $name (Order: $order, Days: $days_display, Approval: $approval_display)"
    done
    
    echo ""
    read -p "Enter stage ID to edit: " stage_id
    
    if [[ ! "$stage_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid stage ID${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Get current stage data
    local current_data=$(sqlite3 "$WORKFLOW_DB" "
        SELECT stage_name, stage_description, stage_order, days_in_stage, ou_path, 
               requires_approval, color_code, icon
        FROM suspension_stages WHERE id = $stage_id;
    ")
    
    if [[ -z "$current_data" ]]; then
        echo -e "${RED}Stage not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    IFS='|' read -r curr_name curr_desc curr_order curr_days curr_ou curr_approval curr_color curr_icon <<< "$current_data"
    
    echo ""
    echo -e "${WHITE}Current values (press Enter to keep current):${NC}"
    echo "Current name: $curr_name"
    read -p "New name: " new_name
    [[ -z "$new_name" ]] && new_name="$curr_name"
    
    echo "Current description: $curr_desc"
    read -p "New description: " new_desc
    [[ -z "$new_desc" ]] && new_desc="$curr_desc"
    
    echo "Current order: $curr_order"
    read -p "New order: " new_order
    [[ -z "$new_order" ]] && new_order="$curr_order"
    
    echo "Current days in stage: ${curr_days:-'unlimited'}"
    read -p "New days in stage (empty for unlimited): " new_days
    [[ -z "$new_days" ]] && new_days="$curr_days"
    [[ -z "$new_days" ]] && new_days="NULL"
    
    echo "Current OU: $curr_ou"
    read -p "New OU path: " new_ou
    [[ -z "$new_ou" ]] && new_ou="$curr_ou"
    
    echo "Current requires approval: $([ "$curr_approval" = "1" ] && echo "Yes" || echo "No")"
    read -p "Requires approval? (y/n, Enter to keep current): " new_approval_input
    local new_approval="$curr_approval"
    if [[ -n "$new_approval_input" ]]; then
        [[ "$new_approval_input" =~ ^[Yy] ]] && new_approval=1 || new_approval=0
    fi
    
    # Update stage
    local result=$(sqlite3 "$WORKFLOW_DB" "
        UPDATE suspension_stages 
        SET stage_name = '$new_name',
            stage_description = '$new_desc',
            stage_order = $new_order,
            days_in_stage = $new_days,
            ou_path = '$new_ou',
            requires_approval = $new_approval,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $stage_id;
    " 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Stage updated successfully${NC}"
    else
        echo -e "${RED}Error updating stage: $result${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Load predefined workflow template
load_workflow_template() {
    echo -e "${CYAN}=== Load Workflow Template ===${NC}"
    echo ""
    
    # Show available templates
    echo -e "${WHITE}Available Templates:${NC}"
    sqlite3 "$WORKFLOW_DB" "
        SELECT id, template_name, template_description, organization_type
        FROM workflow_templates
        ORDER BY is_default DESC, template_name;
    " | while IFS='|' read -r id name desc org_type; do
        echo "$id. $name ($org_type)"
        echo "   Description: $desc"
        echo ""
    done
    
    read -p "Enter template ID to load (or 'c' to cancel): " template_id
    
    if [[ "$template_id" = "c" ]]; then
        return
    fi
    
    if [[ ! "$template_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid template ID${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Warning: This will replace your current workflow configuration.${NC}"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Operation cancelled"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Deactivate current stages
    sqlite3 "$WORKFLOW_DB" "UPDATE suspension_stages SET is_active = 0;"
    
    # Load template stages
    sqlite3 "$WORKFLOW_DB" "
        INSERT INTO suspension_stages 
        (stage_name, stage_description, stage_order, days_in_stage, ou_path, 
         requires_approval, color_code, icon, is_active)
        SELECT stage_name, stage_description, stage_order, days_in_stage, ou_path,
               requires_approval, color_code, icon, 1
        FROM template_stages 
        WHERE template_id = $template_id
        ORDER BY stage_order;
    "
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Template loaded successfully${NC}"
        echo ""
        show_workflow_status
    else
        echo -e "${RED}Error loading template${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Main workflow manager menu
workflow_manager_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== GWOMBAT Suspension Workflow Manager ===${NC}"
        echo ""
        
        echo -e "${CYAN}Configure and manage your organization's suspension lifecycle stages${NC}"
        echo ""
        
        echo "1. 📊 View current workflow status"
        echo "2. ⚙️  Manage workflow stages"
        echo "3. 👥 Move accounts between stages"
        echo "4. 📈 View workflow reports"
        echo "5. 🔄 Bulk stage operations"
        echo "6. 🗂️  Import/Export workflow configuration"
        echo "7. 📋 Workflow templates"
        echo ""
        echo "8. 🔧 Initialize workflow database"
        echo ""
        echo "9. ↩️  Return to main menu"
        echo ""
        
        read -p "Select option (1-9): " choice
        
        case $choice in
            1) 
                clear
                show_workflow_status
                read -p "Press Enter to continue..."
                ;;
            2) manage_workflow_stages ;;
            3) echo "Feature coming soon..."; read -p "Press Enter to continue..." ;;
            4) echo "Feature coming soon..."; read -p "Press Enter to continue..." ;;
            5) echo "Feature coming soon..."; read -p "Press Enter to continue..." ;;
            6) echo "Feature coming soon..."; read -p "Press Enter to continue..." ;;
            7) 
                clear
                load_workflow_template
                ;;
            8)
                echo -e "${CYAN}Initializing workflow database...${NC}"
                init_workflow_db "$WORKFLOW_DB"
                read -p "Press Enter to continue..."
                ;;
            9) return ;;
            *) 
                echo -e "${RED}Invalid option${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# If script is called directly, run the menu
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    workflow_manager_menu
fi