# GWOMBAT Testing Guide

## Basic Testing Requirements

### Fundamental Testing Principles
Any testing of GWOMBAT must include these basic steps to ensure the application actually works:

1. **Start the application normally** (`./gwombat.sh`)
2. **Navigate through each major menu option** (1-10)
3. **Test basic user workflows end-to-end**
4. **Verify database connectivity and menu generation**
5. **Test navigation options** (search, index, exit)
6. **Validate error handling** (invalid inputs, missing files)

### Critical Testing Lesson
The August 2025 "Comprehensive QA Testing" failed to detect that the main menu was completely broken due to missing database tables. This demonstrates that testing claims must be verifiable and that basic user interaction testing is fundamental to any QA process.

**Testing is not comprehensive unless it includes actual user interaction with the application.**

## Comprehensive Security Testing Framework

Act as a Senior QA Security Engineer and perform comprehensive testing on GWOMBAT.
Your mission is to break the application and find vulnerabilities. Be thorough, creative,
and malicious in your testing approach (for defensive security purposes).

### Testing Scope:

#### 1. Security Testing
- **Input validation**: Test all user inputs with:
  - SQL injection (`'; DROP TABLE; --`, `UNION SELECT`, etc.)
  - Command injection (`;`, `ls`, `$(whoami)`, `` `rm -rf` ``)
  - Path traversal (`../`, `....///`, `%2e%2e%2f`)
  - XSS/Script injection (`<script>`, `javascript:`, `onerror=`)
  - XXE injection (if XML processing)
  - LDAP/NoSQL injection (if applicable)
- **Authentication/Authorization**:
  - Privilege escalation attempts
  - Session hijacking
  - Token manipulation
- **File operations**:
  - Symlink attacks
  - Race conditions (TOCTOU)
  - Arbitrary file read/write
  - Zip bombs/decompression attacks

#### 2. Input Fuzzing
- **Boundary testing**:
  - Empty strings, null bytes (`\x00`)
  - Extremely long strings (10MB+)
  - Integer overflow (`999999999999999999`)
  - Negative numbers where positive expected
  - Special characters (`!@#$%^&*(){}[]|\\:";'<>?,./~``)
  - Unicode edge cases (emoji, RTL text, zero-width chars)
  - Different encodings (UTF-16, Latin-1, etc.)
- **Type confusion**:
  - String where number expected
  - Array where string expected
  - Objects in primitive fields

#### 3. Concurrency Testing
- Race conditions in file operations
- Database transaction conflicts
- Thread safety violations
- Deadlock scenarios
- Resource contention

#### 4. Resource Exhaustion
- Memory leaks and OOM conditions
- CPU spinning/infinite loops
- Disk space exhaustion
- File descriptor limits
- Network connection limits
- Fork bombs

#### 5. Error Handling
- Forcing every error path
- Exception handling gaps
- Stack trace information leaks
- Error message injection
- Crash recovery testing

#### 6. Platform-Specific Testing
- OS command variations (Windows vs Linux vs Mac)
- File system differences (case sensitivity, path separators)
- Permission models
- Network behaviors
- Shell escape sequences

#### 7. Business Logic Testing
- State manipulation
- Workflow bypass attempts
- Time-based attacks (TOCTOU)
- Logic bombs
- Replay attacks

#### 8. Integration Testing
- External service failures
- API timeout scenarios
- Partial failure handling
- Dependency version conflicts
- Network partition scenarios

#### 9. Performance Testing
- Load testing (simulate 1000+ concurrent users)
- Stress testing (push beyond limits)
- Memory profiling
- Database query optimization
- Caching effectiveness

#### 10. Cryptography (if applicable)
- Weak algorithms
- Hardcoded keys/secrets
- Insufficient randomness
- Timing attacks
- Padding oracle attacks

## Testing Methodology:

1. **Static Analysis First**: Review code for obvious vulnerabilities
2. **Dynamic Testing**: Run the application with malicious inputs
3. **Automated Scanning**: Use tools if available
4. **Manual Exploitation**: Try to exploit found vulnerabilities
5. **Chained Attacks**: Combine multiple vulnerabilities

## Deliverables:

For EVERY issue found:
1. Create a GitHub issue with:
   - Clear title describing the vulnerability
   - Severity rating (Critical/High/Medium/Low)
   - Detailed description
   - Steps to reproduce
   - Proof of concept code/commands
   - Impact assessment
   - Suggested fixes

2. Continue testing even after finding critical issues
3. Test both happy paths and edge cases
4. Assume the user is malicious and creative
5. Check for defense in depth failures

## Additional Testing Areas:

- Configuration file security
- Log injection attacks
- Cache poisoning
- SSRF vulnerabilities
- DNS rebinding
- Clickjacking
- Open redirects
- Information disclosure
- Side-channel attacks
- Supply chain vulnerabilities

## GWOMBAT-Specific Testing Focus:

### Database Security
- Test SQL injection in all database queries
- Verify parameterized queries are used consistently
- Test database file permissions (menu.db should be read-only)
- Verify database path resolution across different working directories

### Menu System Security
- Test menu option parsing with malicious inputs
- Verify function name resolution can't be hijacked
- Test search functionality with injection attempts
- Verify menu navigation bounds checking

### GAM Integration Security
- Test GAM command injection through user inputs
- Verify OAuth token security
- Test domain verification bypass attempts
- Check for credential exposure in logs

### File Operation Security
- Test path traversal in all file operations
- Verify safe handling of user-provided file paths
- Test symlink attack vectors
- Check temporary file security

### Environment Configuration Security
- Test .env file parsing for injection
- Verify configuration override security
- Test environment variable injection
- Check for hardcoded secrets

## Testing Mindset:
- Think like an attacker
- Question every assumption
- Test what developers forgot to test
- Combine multiple small issues into larger attacks
- Consider real-world attack scenarios

## Testing Commands

### Basic Functionality Testing
```bash
# Test main menu loads
./gwombat.sh

# Test each major menu (1-10)
echo "1" | ./gwombat.sh  # User & Group Management
echo "2" | ./gwombat.sh  # File & Drive Operations
echo "5" | ./gwombat.sh  # Dashboard & Statistics
# etc.

# Test search functionality
echo -e "s\nuser\nx" | ./gwombat.sh

# Test navigation
echo -e "1\np\nx" | ./gwombat.sh  # Go to submenu, previous, exit
```

### Database Testing
```bash
# Test database file existence and permissions
ls -la shared-config/menu.db
sqlite3 shared-config/menu.db ".tables"
sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_sections;"

# Test database functions directly
source shared-utilities/database_functions.sh
generate_main_menu
```

### Security Testing Examples
```bash
# Test SQL injection in search
echo -e "s\n'; DROP TABLE menu_sections; --\nx" | ./gwombat.sh

# Test command injection in menu selection
echo -e "1; rm -rf /tmp/*\nx" | ./gwombat.sh

# Test path traversal
echo -e "../../../etc/passwd\nx" | ./gwombat.sh
```

Report ALL findings, even if they seem minor - small issues can often be chained into 
critical vulnerabilities.