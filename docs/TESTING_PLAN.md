# GWOMBAT Quality Assurance Testing Plan

## 🎯 **TESTING PHILOSOPHY: BREAK IT TO IMPROVE IT**

You are to assume the role of a professional quality assurance expert. Your job is to test every menu option and every area of this application to make sure everything is working as expected. 

**Goal**: Find errors, bugs, and edge cases by acting as a professional QA agent whose mission is to stress test every interface, menu, and input field. **Finding errors is success** - document them and continue testing.

When you are done testing and cannot find any errors then we will certify this as fully tested. If a user finds an error after you are done, you have failed.

## 📊 **CURRENT QA TESTING STATUS**

**Functions Actually Tested**: ~25-30 (User management, file operations, GAM commands, database operations)  
**Functions Requiring Testing**: **~30 remaining menu options** 

**Critical Issues Found So Far**: 8 (GitHub issues #10-#17)
- Issue #10: Main menu infinite error loop (HIGH)
- Issue #11: Account Analysis menu placement (MEDIUM)  
- Issue #12: 🔥 SQL injection vulnerability (CRITICAL SECURITY)
- Issue #13: Account Analysis tools lost during restore (HIGH)
- Issue #14: Function 3 invalid storage GAM syntax (MEDIUM)
- Issue #15: Function 8 invalid group GAM syntax (MEDIUM) 
- Issue #16: Shared drive operations blocked by Drive API (HIGH)
- Issue #17: Function 2 invalid teamdrive GAM syntax (MEDIUM)

**Testing Completed**: ~70% - User lifecycle, GAM operations, database functions, CSV export, bulk operations
**Testing Remaining**: ~90% - **YOU MUST TEST EVERY POSSIBLE MENU OPTION AND CHOICE**

⚠️ **TESTING IS NOT COMPLETE** - Continue systematic testing of ALL functions:
- Create users, delete them, suspend them
- Use GYB to back them up
- Test every CSV export option
- Test every backup and recovery function
- Test every permission management tool
- Test every shared drive operation
- Test every analysis and discovery tool
- Test every dashboard and statistics function
- Test every system administration option

**DO NOT STOP until you have tested every possible menu option and choice. Turn over every rock and search every nook and cranny of this application.**

## 📋 **ERROR TRACKING**
- **ALL ERRORS** must be immediately documented in `TO-DO.md`
- **DO NOT STOP TESTING** to fix errors - continue testing and document everything
- **TEST METHODOLOGY**: Navigate menus as a real user would, not via API calls or file scanning

All sections relying on GAM commands should work without error. If any fail then they were created outside of strictly following the syntax advertised in the GAM wiki and their repair should be added as a critical level to do item.

While you are testing you can create, edit, suspend, and delete accounts as needed. Do not delete any current accounts or files. If you find any errors that allow you to execute shell commands do not try commands that could damage the account the application is running under, simply proving that you found the ability to execute a command is a victory.
---

## 🔍 **TESTING SECTIONS**

### **SECTION 1: Main Menu Navigation Testing**
**Status**: ⏳ PENDING

**Test Steps**:
1. Launch `./gwombat.sh`
2. Verify main menu displays with 8 options from database
3. Test each numbered option (1-8):
   - **Option 1**: User & Group Management (23 functions)
   - **Option 2**: File & Drive Operations (42 functions across 3 submenus)
   - **Option 3**: Analysis & Discovery (3 submenus with Account Analysis, File Discovery, System Diagnostics)
   - **Option 4**: Account List Management
   - **Option 5**: Dashboard & Statistics (17 dashboard + 8 statistics functions)
   - **Option 6**: Reports & Monitoring 
   - **Option 7**: System Administration (15 functions)
   - **Option 8**: SCuBA Compliance Management
4. Test navigation options:
   - **c**: Configuration Management
   - **s**: Search Menu Options
   - **i**: Menu Index (Alphabetical)
   - **x**: Exit
5. Test invalid inputs: letters, symbols, numbers outside range
6. Test edge cases: empty input, extremely long input, special characters

**QA Agent Instructions**: 
- Try to break the menu by entering unexpected values
- Test ALL options, even if they seem similar
- Document any crashes, error messages, or unexpected behavior

---

### **SECTION 2: Dashboard & Statistics Menu Testing**
**Status**: ⏳ PENDING

**Subsection 2A: Main Dashboard (17 menu items)**
1. Navigate to Dashboard & Statistics → Main Dashboard
2. Test each of the 17 dashboard options:
   - Verify each loads without error
   - Test with different data states (empty database, populated database)
   - Try rapid menu navigation
3. Test invalid inputs in dashboard menus
4. Verify statistics display correctly

**Subsection 2B: Statistics & Metrics (8 menu items)**  
1. Navigate to Dashboard & Statistics → Statistics & Metrics
2. Test all 8 statistical functions:
   - Domain Overview Statistics
   - User Account Statistics  
   - Historical Trends
   - Storage Analytics
   - Group Statistics
   - System Performance
   - Database Performance
   - GAM Operation Metrics
3. Test with various database states
4. Verify error handling when GAM unavailable

**QA Agent Instructions**:
- Focus on breaking statistics calculations
- Test with edge case data (0 accounts, malformed data)
- Verify all charts/displays render properly

---

### **SECTION 3: Analysis & Discovery Testing**
**Status**: ⏳ PENDING

**Subsection 3A: Account Analysis Menu (20 comprehensive tools)**
**NEWLY CONVERTED TO SQLITE - PRIORITY TESTING**

1. Navigate to Analysis & Discovery → Account Analysis
2. Verify menu displays all 20 tools organized in 5 categories:
   - **Account Discovery (1-4)**: Search Accounts, Profile Analysis, Department Analysis, Email Patterns
   - **Usage Analysis (5-8)**: Storage Usage, Login Activity, Account Activity, Drive Usage
   - **Security Analysis (9-12)**: Security Profile, 2FA Adoption, Admin Access, Risk Assessment  
   - **Lifecycle Analysis (13-16)**: Lifecycle Analysis, Account Age, Growth Analysis, Health Scoring
   - **Comparative Analysis (17-20)**: Department Comparison, Year-over-Year, Benchmark, Batch Analysis

3. Test each of the 20 functions systematically:
   - Verify function dispatcher calls correct functions
   - Test with valid and invalid account inputs
   - Test with edge cases (non-existent accounts, malformed emails)

**Subsection 3B: File Discovery Menu**
1. Navigate to Analysis & Discovery → File Discovery
2. Test file discovery functions
3. Test with invalid file paths and URLs

**Subsection 3C: System Diagnostics Menu** 
1. Navigate to Analysis & Discovery → System Diagnostics
2. Test diagnostic functions
3. Verify system health checks work correctly

**QA Agent Instructions**:
- **Priority focus on Account Analysis menu** - this was just converted from fallback to SQLite
- Test every single analysis function to ensure database integration works
- Try malformed account inputs, test with empty database
- Verify all 20 tools load and execute without errors

---

### **SECTION 4: File Operations & Management Testing**
**Status**: ⏳ PENDING

**Subsection 4A: File Operations (3 streamlined options)**
1. Navigate to File & Drive Operations → File Operations
2. Test each of the 3 streamlined file operation functions
3. Test with invalid file paths, malformed URLs, empty inputs

**Subsection 4B: Permission Management (20 menu items)**
1. Navigate to File & Drive Operations → Permission Management  
2. Systematically test all 20 permission functions
3. Test error handling for invalid users, malformed permissions

**Subsection 4C: Shared Drive Management (19 comprehensive functions)**
1. Navigate to File & Drive Operations → Shared Drive Management
2. Test all 19 shared drive functions
3. Test with invalid drive IDs, malformed URLs

**QA Agent Instructions**:
- Try malformed Google Drive URLs
- Test with non-existent user accounts
- Attempt operations with insufficient permissions

---

### **SECTION 5: System Administration Testing**
**Status**: ⏳ PENDING

**Subsection 5A: System Administration (15 menu items)**
1. Navigate to System Administration
2. Test all 15 administrative functions
3. Verify database operations work correctly
4. Test backup and maintenance functions

**Subsection 5B: Reports & Maintenance (via Reports & Monitoring menu)**
1. Navigate to Reports & Monitoring → Reports & Maintenance
2. Test all reporting functions
3. Verify log cleanup operations
4. Test backup management functions

**QA Agent Instructions**:
- Test database operations with corrupted data
- Try backup operations with insufficient disk space
- Test log operations with missing log files

---

### **SECTION 6: Configuration & Setup Testing**
**Status**: ⏳ PENDING

**Subsection 6A: System Configuration (5+ menu items)**
1. Navigate to Configuration Management → System Configuration
2. Test setup wizard functionality
3. Test domain configuration changes
4. Test Python environment setup
5. Test configuration backup/restore

**Subsection 6B: External Tools Configuration**
1. Test GAM configuration options
2. Test GYB integration settings
3. Test rclone configuration

**QA Agent Instructions**:
- Try configuring invalid domains
- Test with missing external tools
- Attempt configuration with corrupted config files

---

### **SECTION 7: Backup & Recovery Testing**
**Status**: ⏳ PENDING

**Test All Backup Functions**:
1. Navigate to Backup & Recovery
2. Systematically test all Gmail backup options
3. Test Drive backup functionality  
4. Test system backup operations
5. Test backup verification
6. Test disaster recovery procedures

**QA Agent Instructions**:
- Test backups with insufficient storage
- Try restoring from corrupted backups
- Test backup operations with network issues

---

### **SECTION 8: Edge Case & Error Testing**
**Status**: ⏳ PENDING

**Database Edge Cases**:
1. Test with empty database
2. Test with corrupted database
3. Test with missing database files
4. Test with insufficient permissions

**Input Validation Testing**:
1. Test all input fields with:
   - Empty strings
   - Extremely long inputs (1000+ characters)
   - Special characters: `'; DROP TABLE--`
   - Unicode characters
   - Binary data
   - HTML/XML tags

**Network & External Dependencies**:
1. Test with no internet connection
2. Test with GAM unavailable
3. Test with Google API limits exceeded
4. Test with invalid credentials

**QA Agent Instructions**:
- **BE CREATIVE WITH BREAKING THINGS**
- Try every possible way to crash the system
- Test rapid navigation, simultaneous operations
- Document everything that doesn't work as expected

---

### **SECTION 9: Search & Navigation Testing**  
**Status**: ⏳ PENDING

**Search Functionality**:
1. Test menu search function (option 's')
2. Try various search terms
3. Test search with invalid queries
4. Test alphabetical index (option 'i')

**Navigation Consistency**:
1. Verify 'p' (previous), 'm' (main), 'x' (exit) work in ALL menus
2. Test navigation from deep menu levels
3. Test rapid menu switching

**QA Agent Instructions**:
- Try to get lost in the menu system
- Test navigation edge cases
- Verify consistent behavior across all menus

---

## 📊 **SUCCESS METRICS**

**Testing is considered successful when**:
- **Every menu option has been tested**
- **Invalid inputs have been tried in every field**
- **All errors are documented in TO-DO.md**
- **Edge cases have been systematically explored**
- **System behavior is predictable and documented**

## 🚨 **ERROR DOCUMENTATION TEMPLATE**

When errors are found, add to `TO-DO.md`:
```
## ERROR FOUND - [DATE]
**Location**: [Menu Path] → [Specific Option]
**Error Type**: [Crash/Display Error/Logic Error/etc]
**Steps to Reproduce**: [Exact steps]
**Expected Behavior**: [What should happen]
**Actual Behavior**: [What actually happened]
**Severity**: [High/Medium/Low]
**Testing Continues**: ✓
```

## 🎯 **QA AGENT MINDSET**

**Remember**: You are a professional QA agent whose job is to find problems. Your success is measured by how many issues you uncover. Be systematic, be thorough, and try to break everything. The development team is counting on you to find the bugs before users do.

**Test with the mindset**: "How can I make this fail?"

---

**Ready to begin testing? Start with Section 1 and work systematically through each section. Document everything. Break everything you can. Find those bugs!**
