#!/bin/bash
# GAM7 Compatibility Wrapper for GWOMBAT
# Provides backward compatibility for GAM commands

# Source the main configuration
if [[ -f "./.env" ]]; then
    source "./.env"
fi

# Set GAM path
GAM_PATH="${GAM_PATH:-${GAM:-gam}}"

# GAM7 compatible wrapper function
gam7() {
    local cmd="$1"
    shift
    
    case "$cmd" in
        "print")
            local resource="$1"
            shift
            case "$resource" in
                "users")
                    # Ensure fields are specified for users
                    if [[ "$*" != *"fields"* ]]; then
                        "$GAM_PATH" print users fields primaryEmail,name.fullName,suspended,orgUnitPath "$@"
                    else
                        "$GAM_PATH" print users "$@"
                    fi
                    ;;
                "groups")
                    # Ensure fields are specified for groups
                    if [[ "$*" != *"fields"* ]]; then
                        "$GAM_PATH" print groups fields email,name,description,directMembersCount "$@"
                    else
                        "$GAM_PATH" print groups "$@"
                    fi
                    ;;
                "teamdrives")
                    # Redirect teamdrives to shareddrives
                    echo "Warning: teamdrives is deprecated, using shareddrives" >&2
                    "$GAM_PATH" print shareddrives "$@"
                    ;;
                *)
                    "$GAM_PATH" print "$resource" "$@"
                    ;;
            esac
            ;;
        "oauth")
            if [[ "$1" == "create" && "$*" != *"domain"* ]]; then
                echo "Note: Consider adding domain parameter for GAM7" >&2
            fi
            "$GAM_PATH" oauth "$@"
            ;;
        *)
            "$GAM_PATH" "$cmd" "$@"
            ;;
    esac
}

# Export the function for use in scripts
export -f gam7
