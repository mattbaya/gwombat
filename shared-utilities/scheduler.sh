#!/bin/bash

# Background Scheduler for GWOMBAT
# Handles automated execution of scheduled tasks with opt-out capabilities

# Load configuration from .env if available
if [[ -f "../.env" ]]; then
    source ../.env
fi

# Configuration
DB_PATH="${DB_PATH:-./config/gwombat.db}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)_scheduler_$$}"
SCHEDULER_PID_FILE="/tmp/gwombat_scheduler.pid"
SCHEDULER_LOG_FILE="./logs/scheduler.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_DIR="$(dirname "$SCRIPT_DIR")"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Ensure logs directory exists
mkdir -p "$(dirname "$SCHEDULER_LOG_FILE")"

# Database helper function
execute_db() {
    sqlite3 "$DB_PATH" "$1" 2>/dev/null || echo ""
}

# Scheduler logging function
log_scheduler() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$SCHEDULER_LOG_FILE"
    
    # Also log to database if available
    execute_db "
    INSERT INTO system_logs (log_level, session_id, operation, message, source_file)
    VALUES ('$level', '$SESSION_ID', 'scheduler', '$message', 'scheduler.sh');
    " >/dev/null 2>&1
}

# Check if configuration manager is available
check_config_manager() {
    if [[ -x "$SCRIPT_DIR/config_manager.sh" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Get configuration value using config manager
get_config() {
    local section="$1"
    local key="$2"
    local default="$3"
    
    if [[ "$(check_config_manager)" == "true" ]]; then
        local value=$("$SCRIPT_DIR/config_manager.sh" get "$section" "$key" "$default" 2>/dev/null)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# Check if scheduling is enabled globally
is_scheduling_enabled() {
    if [[ "$(check_config_manager)" == "true" ]]; then
        "$SCRIPT_DIR/config_manager.sh" is-scheduling-enabled 2>/dev/null || echo "false"
    else
        echo "false"
    fi
}

# Check if specific task type is allowed
is_task_type_allowed() {
    local task_type="$1"
    
    if [[ "$(check_config_manager)" == "true" ]]; then
        "$SCRIPT_DIR/config_manager.sh" is-task-allowed "$task_type" 2>/dev/null || echo "false"
    else
        echo "false"
    fi
}

# Parse cron pattern and calculate next run time
calculate_next_run() {
    local pattern="$1"
    local current_time=$(date +%s)
    
    # Simple cron pattern parsing (this is a basic implementation)
    case "$pattern" in
        "*/5 * * * *")   # Every 5 minutes
            echo $(date -d "$(date -d @$current_time) + 5 minutes" +%s)
            ;;
        "*/15 * * * *")  # Every 15 minutes
            echo $(date -d "$(date -d @$current_time) + 15 minutes" +%s)
            ;;
        "*/30 * * * *")  # Every 30 minutes
            echo $(date -d "$(date -d @$current_time) + 30 minutes" +%s)
            ;;
        "0 */1 * * *")   # Every hour
            echo $(date -d "$(date -d @$current_time) + 1 hour" +%s)
            ;;
        "0 */6 * * *")   # Every 6 hours
            echo $(date -d "$(date -d @$current_time) + 6 hours" +%s)
            ;;
        "0 6 * * *")     # Daily at 6 AM
            local next_6am=$(date -d "tomorrow 06:00" +%s)
            echo $next_6am
            ;;
        "0 7 * * 1")     # Weekly on Monday at 7 AM
            local next_monday=$(date -d "next Monday 07:00" +%s)
            echo $next_monday
            ;;
        *)
            # Default to 1 hour for unknown patterns
            echo $(date -d "$(date -d @$current_time) + 1 hour" +%s)
            ;;
    esac
}

# Update task next_run time
update_task_schedule() {
    local task_id="$1"
    local pattern="$2"
    
    local next_run_timestamp=$(calculate_next_run "$pattern")
    local next_run_datetime=$(date -d "@$next_run_timestamp" '+%Y-%m-%d %H:%M:%S')
    
    execute_db "
    UPDATE scheduled_tasks 
    SET next_run = '$next_run_datetime'
    WHERE id = $task_id;
    "
}

# Execute a scheduled task
execute_task() {
    local task_id="$1"
    local task_name="$2"
    local task_command="$3"
    local task_type="$4"
    local max_execution_time="$5"
    
    log_scheduler "Starting execution of task: $task_name (ID: $task_id)" "INFO"
    
    # Check if task type is still allowed (opt-out check)
    if [[ "$(is_task_type_allowed "$task_type")" == "false" ]]; then
        log_scheduler "Task $task_name skipped: task type $task_type is not allowed (disabled or opted out)" "WARNING"
        
        execute_db "
        INSERT INTO task_execution_log (task_id, execution_start, execution_end, exit_code, output, triggered_by, session_id)
        VALUES ($task_id, datetime('now'), datetime('now'), 2, 'Task skipped - type not allowed', 'scheduler', '$SESSION_ID');
        "
        return 2
    fi
    
    # Record task start
    local execution_start=$(date '+%Y-%m-%d %H:%M:%S')
    local start_timestamp=$(date +%s)
    
    execute_db "
    INSERT INTO task_execution_log (task_id, execution_start, triggered_by, session_id)
    VALUES ($task_id, '$execution_start', 'scheduler', '$SESSION_ID');
    "
    local execution_log_id=$(execute_db "SELECT last_insert_rowid();")
    
    # Change to GWOMBAT directory before executing command
    cd "$GWOMBAT_DIR" || {
        log_scheduler "Failed to change to GWOMBAT directory: $GWOMBAT_DIR" "ERROR"
        return 1
    }
    
    # Execute the task with timeout
    local output_file="/tmp/gwombat_task_${task_id}_$$"
    local exit_code=0
    
    # Use timeout if available, otherwise just execute
    if command -v timeout >/dev/null 2>&1; then
        timeout "${max_execution_time}s" bash -c "$task_command" > "$output_file" 2>&1
        exit_code=$?
    else
        bash -c "$task_command" > "$output_file" 2>&1
        exit_code=$?
    fi
    
    # Record task completion
    local execution_end=$(date '+%Y-%m-%d %H:%M:%S')
    local end_timestamp=$(date +%s)
    local execution_time=$((end_timestamp - start_timestamp))
    
    # Read task output
    local task_output=""
    if [[ -f "$output_file" ]]; then
        # Limit output size to prevent database bloat
        task_output=$(tail -c 4096 "$output_file" | tr "'" "''")
        rm -f "$output_file"
    fi
    
    # Update execution log
    execute_db "
    UPDATE task_execution_log 
    SET execution_end = '$execution_end',
        exit_code = $exit_code,
        output = '$task_output',
        execution_time_seconds = $execution_time
    WHERE id = $execution_log_id;
    "
    
    # Update task statistics
    if [[ $exit_code -eq 0 ]]; then
        execute_db "
        UPDATE scheduled_tasks 
        SET last_run = '$execution_end',
            run_count = run_count + 1,
            success_count = success_count + 1,
            last_exit_code = $exit_code
        WHERE id = $task_id;
        "
        log_scheduler "Task $task_name completed successfully in ${execution_time}s" "INFO"
    else
        execute_db "
        UPDATE scheduled_tasks 
        SET last_run = '$execution_end',
            run_count = run_count + 1,
            last_exit_code = $exit_code
        WHERE id = $task_id;
        "
        log_scheduler "Task $task_name failed with exit code $exit_code in ${execution_time}s" "ERROR"
        
        # Create failure alert if configured
        local failure_notification=$(get_config "scheduling" "failure_notification_enabled" "true")
        if [[ "$failure_notification" == "true" ]]; then
            execute_db "
            INSERT INTO security_alerts (alert_type, severity, title, description, details)
            VALUES (
                'task_failure', 
                'medium', 
                'Scheduled Task Failure',
                'Task $task_name failed during scheduled execution',
                json_object(
                    'task_name', '$task_name',
                    'task_id', $task_id,
                    'exit_code', $exit_code,
                    'execution_time', $execution_time,
                    'output', '$task_output'
                )
            );
            " >/dev/null 2>&1
        fi
    fi
    
    return $exit_code
}

# Get tasks that are ready to run
get_ready_tasks() {
    execute_db "
    SELECT id, task_name, task_command, task_type, 
           COALESCE(max_execution_time, 300) as max_execution_time,
           schedule_pattern
    FROM scheduled_tasks 
    WHERE is_enabled = 1 
    AND (next_run IS NULL OR next_run <= datetime('now'))
    ORDER BY next_run ASC;
    "
}

# Main scheduler loop
run_scheduler() {
    local max_concurrent=$(get_config "scheduling" "max_concurrent_tasks" "3")
    local running_tasks=0
    
    log_scheduler "Scheduler started (PID: $$, Max concurrent: $max_concurrent)" "INFO"
    
    # Main scheduling loop
    while true; do
        # Check if scheduling is still enabled
        if [[ "$(is_scheduling_enabled)" == "false" ]]; then
            log_scheduler "Scheduling disabled - stopping scheduler" "INFO"
            break
        fi
        
        # Get tasks ready to run
        local ready_tasks=$(get_ready_tasks)
        
        if [[ -n "$ready_tasks" ]]; then
            while IFS='|' read -r task_id task_name task_command task_type max_execution_time schedule_pattern; do
                # Skip empty lines
                [[ -z "$task_id" ]] && continue
                
                # Check if we can start more tasks
                if [[ $running_tasks -ge $max_concurrent ]]; then
                    log_scheduler "Maximum concurrent tasks ($max_concurrent) reached, waiting..." "DEBUG"
                    break
                fi
                
                # Execute task in background
                {
                    execute_task "$task_id" "$task_name" "$task_command" "$task_type" "$max_execution_time"
                    
                    # Update next run time after execution
                    update_task_schedule "$task_id" "$schedule_pattern"
                    
                    # Decrease running task counter (this runs in subshell, so we need to track differently)
                } &
                
                ((running_tasks++))
                log_scheduler "Started background task: $task_name (Running: $running_tasks/$max_concurrent)" "DEBUG"
                
            done <<< "$ready_tasks"
        fi
        
        # Clean up completed background jobs and update counter
        running_tasks=$(jobs -r | wc -l)
        
        # Wait before next iteration
        sleep 30
    done
    
    log_scheduler "Scheduler stopped" "INFO"
}

# Start scheduler as daemon
start_scheduler() {
    # Check if already running
    if [[ -f "$SCHEDULER_PID_FILE" ]]; then
        local pid=$(cat "$SCHEDULER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}Scheduler is already running (PID: $pid)${NC}"
            return 1
        else
            echo -e "${YELLOW}Removing stale PID file${NC}"
            rm -f "$SCHEDULER_PID_FILE"
        fi
    fi
    
    # Check if scheduling is enabled
    if [[ "$(is_scheduling_enabled)" == "false" ]]; then
        echo -e "${RED}Scheduling is disabled. Enable it in configuration first.${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Starting GWOMBAT scheduler...${NC}"
    
    # Start scheduler in background
    nohup bash "$0" _run_daemon > "$SCHEDULER_LOG_FILE" 2>&1 &
    local scheduler_pid=$!
    
    # Save PID
    echo "$scheduler_pid" > "$SCHEDULER_PID_FILE"
    
    # Wait a moment to see if it started successfully
    sleep 2
    if kill -0 "$scheduler_pid" 2>/dev/null; then
        echo -e "${GREEN}✓ Scheduler started successfully (PID: $scheduler_pid)${NC}"
        echo "Log file: $SCHEDULER_LOG_FILE"
        log_scheduler "Scheduler daemon started (PID: $scheduler_pid)" "INFO"
    else
        echo -e "${RED}✗ Failed to start scheduler${NC}"
        rm -f "$SCHEDULER_PID_FILE"
        return 1
    fi
}

# Stop scheduler daemon
stop_scheduler() {
    if [[ ! -f "$SCHEDULER_PID_FILE" ]]; then
        echo -e "${YELLOW}Scheduler is not running${NC}"
        return 1
    fi
    
    local pid=$(cat "$SCHEDULER_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${CYAN}Stopping scheduler (PID: $pid)...${NC}"
        kill "$pid"
        
        # Wait for graceful shutdown
        local count=0
        while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
            sleep 1
            ((count++))
        done
        
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}Scheduler didn't stop gracefully, forcing...${NC}"
            kill -9 "$pid" 2>/dev/null
        fi
        
        rm -f "$SCHEDULER_PID_FILE"
        echo -e "${GREEN}✓ Scheduler stopped${NC}"
        log_scheduler "Scheduler daemon stopped" "INFO"
    else
        echo -e "${YELLOW}Scheduler PID file exists but process is not running${NC}"
        rm -f "$SCHEDULER_PID_FILE"
    fi
}

# Show scheduler status
show_scheduler_status() {
    echo -e "${CYAN}🕐 GWOMBAT Scheduler Status${NC}"
    echo ""
    
    # Check if scheduling is enabled
    local scheduling_enabled=$(is_scheduling_enabled)
    echo -e "Scheduling Enabled: $([ "$scheduling_enabled" == "true" ] && echo "${GREEN}YES${NC}" || echo "${RED}NO${NC}")"
    
    # Check if daemon is running
    local daemon_running="false"
    local daemon_pid=""
    if [[ -f "$SCHEDULER_PID_FILE" ]]; then
        daemon_pid=$(cat "$SCHEDULER_PID_FILE")
        if kill -0 "$daemon_pid" 2>/dev/null; then
            daemon_running="true"
        fi
    fi
    
    echo -e "Scheduler Daemon: $([ "$daemon_running" == "true" ] && echo "${GREEN}RUNNING${NC} (PID: $daemon_pid)" || echo "${RED}STOPPED${NC}")"
    echo ""
    
    # Show configuration
    echo -e "${CYAN}Configuration:${NC}"
    local max_concurrent=$(get_config "scheduling" "max_concurrent_tasks" "3")
    local task_timeout=$(get_config "scheduling" "task_timeout_minutes" "30")
    local log_retention=$(get_config "scheduling" "log_retention_days" "30")
    
    echo "  Max Concurrent Tasks: $max_concurrent"
    echo "  Task Timeout: $task_timeout minutes"
    echo "  Log Retention: $log_retention days"
    echo ""
    
    # Show active tasks
    echo -e "${CYAN}Active Scheduled Tasks:${NC}"
    local active_tasks=$(execute_db "
    SELECT task_name, task_type, 
           CASE 
               WHEN next_run IS NULL THEN 'Not scheduled'
               WHEN next_run <= datetime('now') THEN 'Ready to run'
               ELSE 'Next: ' || strftime('%Y-%m-%d %H:%M', next_run)
           END as status,
           schedule_pattern
    FROM scheduled_tasks 
    WHERE is_enabled = 1
    ORDER BY next_run ASC;
    ")
    
    if [[ -n "$active_tasks" ]]; then
        printf "%-25s %-15s %-20s %s\n" "Task Name" "Type" "Status" "Pattern"
        echo "--------------------------------------------------------------------------------"
        echo "$active_tasks" | while IFS='|' read -r name type status pattern; do
            printf "%-25s %-15s %-20s %s\n" "$name" "$type" "$status" "$pattern"
        done
    else
        echo "  No active scheduled tasks"
    fi
    echo ""
    
    # Show recent executions
    echo -e "${CYAN}Recent Task Executions (last 5):${NC}"
    local recent_executions=$(execute_db "
    SELECT t.task_name, 
           strftime('%m-%d %H:%M', l.execution_start) as start_time,
           CASE WHEN l.exit_code = 0 THEN 'Success' ELSE 'Failed' END as result,
           COALESCE(l.execution_time_seconds, 0) as duration
    FROM task_execution_log l
    JOIN scheduled_tasks t ON l.task_id = t.id
    ORDER BY l.execution_start DESC
    LIMIT 5;
    ")
    
    if [[ -n "$recent_executions" ]]; then
        printf "%-25s %-10s %-10s %s\n" "Task Name" "Time" "Result" "Duration"
        echo "---------------------------------------------------------------"
        echo "$recent_executions" | while IFS='|' read -r name start_time result duration; do
            local result_color="$GREEN"
            [[ "$result" == "Failed" ]] && result_color="$RED"
            printf "%-25s %-10s ${result_color}%-10s${NC} %ss\n" "$name" "$start_time" "$result" "$duration"
        done
    else
        echo "  No recent task executions"
    fi
    echo ""
}

# Run one-time task execution check (for manual testing)
run_once() {
    echo -e "${CYAN}Running one-time task check...${NC}"
    
    if [[ "$(is_scheduling_enabled)" == "false" ]]; then
        echo -e "${RED}Scheduling is disabled${NC}"
        return 1
    fi
    
    local ready_tasks=$(get_ready_tasks)
    if [[ -n "$ready_tasks" ]]; then
        echo "Ready tasks found:"
        echo "$ready_tasks" | while IFS='|' read -r task_id task_name task_command task_type max_execution_time schedule_pattern; do
            [[ -z "$task_id" ]] && continue
            echo "  - $task_name ($task_type)"
            
            # Check if task type is allowed
            if [[ "$(is_task_type_allowed "$task_type")" == "true" ]]; then
                echo "    Status: Allowed - would execute"
            else
                echo "    Status: Blocked - task type not allowed or opted out"
            fi
        done
    else
        echo "No tasks ready to run at this time"
    fi
}

# Command line interface
case "${1:-status}" in
    "start")
        start_scheduler
        ;;
    "stop")
        stop_scheduler
        ;;
    "restart")
        stop_scheduler
        sleep 2
        start_scheduler
        ;;
    "status")
        show_scheduler_status
        ;;
    "run-once")
        run_once
        ;;
    "_run_daemon")
        # Internal command for daemon mode
        run_scheduler
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|run-once}"
        echo ""
        echo "Commands:"
        echo "  start     - Start the scheduler daemon"
        echo "  stop      - Stop the scheduler daemon"
        echo "  restart   - Restart the scheduler daemon"
        echo "  status    - Show scheduler status and configuration"
        echo "  run-once  - Check for ready tasks (testing mode)"
        echo ""
        echo "The scheduler automatically executes scheduled tasks when:"
        echo "  - Master scheduling is enabled in configuration"
        echo "  - Individual task types are not opted out"
        echo "  - Tasks are enabled and their schedule time has arrived"
        exit 1
        ;;
esac