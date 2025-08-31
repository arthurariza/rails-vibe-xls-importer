# Commit Style Rules

## Only **Staged Changes** files should be considered for creating the commit message

## Conventional Commits Format for Commit Messages

- commit_messages
- git
- conventional_commits
- coding_standards
- generate_commit_message

Follow Conventional Commits 1.0.0 specification for all commit messages:

Structure: <type>[optional scope]: <description>

Types:

fix: patches a bug (correlates with PATCH in SemVer)
feat: introduces a new feature (correlates with MINOR in SemVer)
Other allowed types: build:, chore:, ci:, docs:, style:, refactor:, perf:, test:
Breaking changes:

Indicated by ! after type/scope or by a footer BREAKING CHANGE: <description>
Correlates with MAJOR in SemVer
Examples:

feat: add new login feature
fix(auth): resolve token validation issue
docs: update README with installation instructions
feat!: change API response format (breaking change)
refactor(core): improve performance of data processing
Additional rules:

Description should be concise and in imperative mood
Optional body can provide more context after a blank line
Optional footers follow after a blank line (e.g., Refs: #123)
Reference: https://www.conventionalcommits.org/en/v1.0.0/