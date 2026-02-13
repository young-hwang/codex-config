---
name: "gitlab-develop-issue"
description: "Migrate and run the workflow from Claude command gitlab/develop-issue.md. Use when asked to perform tasks matching gitlab-develop-issue, for example: This command guides you through the complete development process for a GitLab issue, from issue review to merge request creation, using spec-kit for systematic "
---

# GitLab Issue Developer

## Overview

Use this skill to execute the existing workflow migrated from `gitlab/develop-issue.md`.
Follow the playbook below and adapt commands to the current repository context.

## Playbook

## Codex Invocation Mapping

If this playbook references slash commands (for example `/plan` or `/tdd`), treat them as skill names in Codex. Ask Codex directly to run the equivalent skill workflow.

# GitLab Issue Developer

This command guides you through the complete development process for a GitLab issue, from issue review to merge request creation, using spec-kit for systematic development.

## Command Usage

Provide issue number: $ARGUMENTS

## Overview

Use this command when the user:
- Wants to start development on a GitLab issue
- Needs a structured development workflow
- Wants to use spec-kit for feature development
- Is ready to develop from issue to merge request

## Step 1: Environment Setup

### 1.1 Fetch Issue Details

Parse issue number from user input ($ARGUMENTS):
- URL format: `https://gitlab.am.micube.dev/{path}/-/issues/176`
- Number format: `176` or `#176`

Fetch and display issue details:

```bash
glab issue view <issue-number>
```

Review the issue description carefully to understand:
- Feature overview
- Purpose and background
- Implementation direction
- Expected test scenarios

## Step 2: Spec-Kit Development Workflow

Once the user is in the worktree environment, guide them through the spec-kit workflow.

**IMPORTANT**: All spec-kit commands (e.g., `/speckit.specify`, `/speckit.plan`) are **Claude Code commands**, NOT bash commands. They should be executed directly in Claude Code CLI, not in a terminal shell.

### 2.1 Constitution (Optional for Simple Tasks)

**When to use:**
- Complex features requiring architectural decisions
- New domains or major refactoring
- Projects without existing constitution

**When to skip:**
- Simple bug fixes
- Minor feature additions
- Well-established project patterns

If needed, execute Claude Code command:
```
/speckit.constitution
```

This defines:
- Project core principles
- Technology stack
- Coding style guidelines
- Architecture patterns

### 2.2 Specify (Required)

**Purpose:** Define WHAT needs to be built.

Execute Claude Code command:
```
/speckit.specify
```

This command creates `spec.md` containing:
- Requirements definition
- User stories
- Acceptance criteria
- Constraints
- Success metrics

**Key Guidelines:**
- Focus on business requirements, not technical implementation
- Use GitLab issue description as primary source
- Write in Korean if issue is in Korean
- Be specific and measurable

### 2.3 Plan (Required)

**Purpose:** Define HOW to implement.

Execute Claude Code command:
```
/speckit.plan
```

This command creates `plan.md` containing:
- Technology selection
- Architecture design
- Data models
- API design
- Implementation strategy
- Risks and mitigations

**Key Guidelines:**
- Reference existing codebase patterns
- Consider Clean Architecture principles
- Plan for testability
- Identify dependencies

### 2.4 Tasks (Required)

**Purpose:** Break down implementation into executable tasks.

Execute Claude Code command:
```
/speckit.tasks
```

This command creates `tasks.md` containing:
- Small, actionable tasks
- Task dependencies
- Estimated effort
- Priority order

**Task Format:**
```markdown
- [ ] Task 1: Create domain entity
- [ ] Task 2: Implement repository interface
- [ ] Task 3: Add application service
- [ ] Task 4: Create REST controller
- [ ] Task 5: Write unit tests
- [ ] Task 6: Write integration tests
```

### 2.5 Implement (Required)

**Purpose:** Execute the implementation.

Execute Claude Code command:
```
/speckit.implement
```

**Implementation Guidelines:**
1. **Follow the task list** - Complete tasks in order
2. **Commit frequently** - Small, logical commits
3. **Write tests** - Unit and integration tests as you go
4. **Follow project conventions** - Use existing patterns
5. **Document as needed** - Add comments for complex logic
6. **Run tests regularly** - Ensure nothing breaks

**During Implementation:**
- Update `tasks.md` as tasks are completed
- Keep `spec.md` and `plan.md` updated if requirements change
- Use TodoWrite tool to track progress
- Mark each task as completed when done

### 2.6 Checklist (Required After Implementation)

**Purpose:** Verify implementation quality and completeness.

Execute Claude Code command:
```
/speckit.checklist
```

**Verification Areas:**
1. **Requirements Completeness**
   - All acceptance criteria met
   - All user stories implemented
   - No missing features

2. **Code Quality**
   - Follows coding standards
   - No code smells
   - Proper error handling
   - Adequate test coverage

3. **Security**
   - No security vulnerabilities
   - Input validation
   - Proper authentication/authorization
   - No sensitive data exposure

4. **Performance**
   - No obvious performance issues
   - Efficient database queries
   - Proper caching where needed

5. **Accessibility**
   - User-friendly error messages
   - Proper logging
   - Documentation updated

6. **Testing**
   - Unit tests pass
   - Integration tests pass
   - Edge cases covered
   - Test data cleanup

**Action Items:**
- Fix any issues found during checklist review
- Document any known limitations
- Update implementation if needed

---

## Phase 3: Merge Request Creation

### 3.1 Prepare for MR

Before creating the merge request, ensure:

1. **All changes are committed:**
   ```bash
   git status
   ```

2. **All tests pass:**
   ```bash
   ./gradlew test
   # or appropriate test command for the project
   ```

3. **Build succeeds:**
   ```bash
   ./gradlew build
   ```

4. **Branch is up to date:**
   ```bash
   git fetch origin develop
   git rebase origin/develop
   ```

### 3.2 Review Changes

Review the full diff:

```bash
git diff origin/develop...HEAD
```

Verify:
- No debug code or console.log statements
- No commented-out code
- No TODO comments (or track them)
- No sensitive information

### 3.3 Create Merge Request

Execute Claude Code command:
```
/gitlab:create-mr
```

**CRITICAL: Use the MR template**

The MR description MUST follow template structure and be written in **Korean**.

**Template Structure:**

```markdown
## Type of Change
- [x] New feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Refactoring
- [ ] Hotfix
- [ ] Security patch
- [ ] UI/UX improvement

## Changes
[변경 사항에 대해 자세히 설명해주세요. 이러한 변경을 수행한 이유와 관련된 배경도 포함해주세요.]

구현 내용을 상세히 작성:
- 추가된 기능
- 변경된 로직
- 영향받는 컴포넌트
- 기술적 결정 사항

## Issue
Closes #<issue-number>

## Checklist
- [x] 제 코드는 프로젝트의 코딩 및 스타일 가이드라인을 준수합니다.
- [x] 제 코드를 자체 검토하였습니다.
- [x] 특히 이해하기 어려운 부분에 대해 제 코드에 주석을 작성하였습니다.
- [x] 문서에도 해당 변경 사항을 반영하였습니다.
- [x] 제 변경 사항은 새로운 경고를 발생시키지 않습니다.

## Additional Information
[리뷰어가 알아야 할 추가 정보가 있다면 작성해주세요.]
```

**MR Description Guidelines:**
1. **Title**: Use issue title or concise description
2. **Type of Change**: Check appropriate boxes
3. **Changes Section**: Write detailed explanation in Korean
   - What was implemented
   - Why it was implemented this way
   - What components are affected
   - Any technical decisions made
4. **Issue Reference**: Use `Closes #<issue-number>` format
5. **Checklist**: Check all applicable items
6. **Additional Information**: Include any context for reviewers

### 3.4 Post-MR Actions

After MR is created:

1. **Verify MR link:**
   - Copy and share the MR URL with the user
   - Example: `https://gitlab.com/{path}/-/merge_requests/123`

2. **Assign reviewers** (if needed):
   ```bash
   glab mr update <mr-number> --assignee <username>
   ```

3. **Add labels** (if needed):
   ```bash
   glab mr update <mr-number> --label "feature,needs-review"
   ```

4. **Wait for review**:
   - Inform user to wait for review feedback
   - Address review comments if requested

---

## Complete Workflow Summary

**High-Level Flow:**
```
1. GitLab Issue → 2. Worktree Setup → 3. Spec-Kit Workflow → 4. Implementation → 5. Quality Check → 6. MR Creation
```

**Detailed Steps:**
1. ✓ Fetch and understand issue
2. ✓ Create worktree and development environment
3. ✓ (Optional) Define constitution for complex tasks
4. ✓ Specify requirements (spec.md)
5. ✓ Plan implementation (plan.md)
6. ✓ Break down into tasks (tasks.md)
7. ✓ Implement features and tests
8. ✓ Run quality checklist
9. ✓ Create merge request in Korean using template
10. ✓ Assign reviewers and wait for approval

---

## Error Handling

### glab Not Installed
- Execute check script which provides installation instructions
- Stop workflow until resolved

### Worktree Creation Failed
- Check if worktree already exists
- Check if branch already exists remotely
- Provide manual worktree commands

### Spec-Kit Command Failed
- Verify spec-kit is initialized
- Check if previous step is completed
- Review generated files for issues

### Tests Failed
- Fix failing tests before creating MR
- Update implementation as needed
- Re-run checklist

### Build Failed
- Fix build errors
- Verify all dependencies
- Check for compilation errors

### MR Creation Failed
- Ensure changes are committed
- Verify branch is pushed to remote
- Check glab authentication

---

## Best Practices

### Development Process
1. **Understand first, code later** - Thoroughly review the issue
2. **Plan before implementing** - Complete spec-kit workflow in order
3. **Test as you go** - Don't wait until the end
4. **Commit frequently** - Small, logical commits with clear messages
5. **Follow conventions** - Use existing project patterns

### Code Quality
1. **Clean Architecture** - Respect layer boundaries
2. **SOLID Principles** - Single responsibility, dependency inversion
3. **DRY** - Don't repeat yourself
4. **YAGNI** - You aren't gonna need it (don't over-engineer)
5. **Code Review Ready** - Self-review before creating MR

### Communication
1. **Korean for business** - Write specs, MRs, and docs in Korean
2. **Clear commit messages** - Explain what and why
3. **Detailed MR descriptions** - Help reviewers understand changes
4. **Document decisions** - Record important technical decisions

### Spec-Kit Usage
1. **Don't skip steps** - Each phase builds on the previous
2. **Update as you go** - Keep spec/plan/tasks synchronized
3. **Review checklist thoroughly** - Don't rush quality checks
4. **Save artifacts** - Keep spec.md, plan.md, tasks.md in repo

---

## Dependencies

### Required Tools
- `glab` - GitLab CLI
- `git` - Version control
- `tmux` - Terminal multiplexer (optional but recommended)
- Spec-kit - Development methodology tools

### Required Scripts
- `~/.claude/scripts/check_glab.sh`
- `~/.claude/scripts/git-create-worktree.sh`
- `~/.claude/scripts/spec-kit-init.sh`
- `~/.claude/scripts/tmux-create-session.sh`

### Required Files
- `.gitlab/merge_request_templates/default.md` - MR template

### Claude Code Commands (Not Bash Commands)

**IMPORTANT**: These are Claude Code commands, not bash commands. Execute them directly in Claude Code CLI.

- `/speckit.constitution` - Define project principles and guidelines
- `/speckit.specify` - Create requirements specification (spec.md)
- `/speckit.plan` - Create implementation plan (plan.md)
- `/speckit.tasks` - Generate task breakdown (tasks.md)
- `/speckit.implement` - Execute implementation following tasks
- `/speckit.checklist` - Verify implementation quality
- `/gitlab:create-mr` - Create merge request using Korean template

---

## Examples

### Example 1: Complete Feature Development

```
User: /gitlab-develop-issue https://gitlab.com/{path}/-/issues/176

Claude executes:

Phase 1: Environment Setup
1. ✓ Check glab installation
2. ✓ Fetch issue #176: "feat: add validator to support validation check for entity, record"
3. ✓ Create worktree: ../worktrees/feature/176-add-validator
4. ✓ Initialize spec-kit
5. ✓ Create tmux session: 176

Phase 2: Spec-Kit Workflow (User continues in tmux session)
1. Skip /speckit.constitution (simple feature)
2. ✓ /speckit.specify - Create spec.md with requirements
3. ✓ /speckit.plan - Create plan.md with implementation strategy
4. ✓ /speckit.tasks - Break down into 8 tasks
5. ✓ /speckit.implement - Implement Validator classes and tests
6. ✓ /speckit.checklist - Verify all quality checks pass

Phase 3: MR Creation
1. ✓ Run tests and build
2. ✓ Review changes
3. ✓ Create MR using template in Korean
4. ✓ MR created: https://gitlab.com/{path}/-/merge_requests/123

Result: Complete feature implemented with proper documentation and tests
```

### Example 2: Bug Fix

```
User: /gitlab-develop-issue 180

Claude executes:

Phase 1: Environment Setup
1. ✓ Fetch issue #180: "bug: fix calendar"
2. ✓ Create worktree: ../worktrees/feature/180-fix-calendar

Phase 2: Spec-Kit Workflow
1. Skip /speckit.constitution (bug fix)
2. ✓ /speckit.specify - Document bug and expected behavior
3. ✓ /speckit.plan - Plan fix approach
4. ✓ /speckit.tasks - 3 tasks: identify issue, fix logic, add test
5. ✓ /speckit.implement - Fix validation logic
6. ✓ /speckit.checklist - Verify fix and test coverage

Phase 3: MR Creation
1. ✓ Create MR with "Bug fix" type checked
2. ✓ MR includes detailed explanation of bug and fix

Result: Bug fixed with regression test
```

---

## Usage Tips

### Starting Development
1. Always use this skill at the start of a new issue
2. Don't skip environment setup - it ensures consistency
3. Read the issue thoroughly before proceeding

### During Development
1. Follow spec-kit workflow in order
2. Update task list as you progress
3. Commit frequently with clear messages
4. Run tests regularly

### Before MR
1. Complete all checklist items
2. Review your own changes
3. Ensure tests pass
4. Update documentation

### After MR Creation
1. Monitor for review feedback
2. Address comments promptly
3. Keep MR up to date with develop branch

---

## Notes

- This skill combines multiple workflows into one complete process
- It enforces best practices and quality standards
- All documentation should be in Korean for business communication
- Code comments can be in English or Korean based on team preference
- The workflow is designed for Clean Architecture projects
- Spec-kit files (spec.md, plan.md, tasks.md) should be committed to the repository

---

## Skill Invocation

This skill is invoked with:
```bash
/gitlab-develop-issue <issue-url-or-number>
```

Examples:
```bash
/gitlab-develop-issue https://gitlab.com/{path}/-/issues/176
/gitlab-develop-issue 176
/gitlab-develop-issue #176
```

The skill will guide you through each phase, ensuring nothing is missed and best practices are followed throughout the development lifecycle.
