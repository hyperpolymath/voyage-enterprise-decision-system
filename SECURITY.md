# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please report it responsibly.

### How to Report

1. **Email**: Send details to [security@hyperpolymath.org](mailto:security@hyperpolymath.org)
2. **Encrypted Reports**: Use our GPG key at https://hyperpolymath.org/gpg/security.asc
3. **Do NOT** create public GitHub issues for security vulnerabilities

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

| Stage | Timeframe |
|-------|-----------|
| Initial acknowledgment | 48 hours |
| Severity assessment | 5 business days |
| Fix development | Varies by severity |
| Public disclosure | After fix is released |

### Severity Classification

- **Critical**: Remote code execution, authentication bypass, data exposure
- **High**: Privilege escalation, significant data leak
- **Medium**: Limited data exposure, denial of service
- **Low**: Minor issues with limited impact

### Safe Harbor

We consider security research conducted in good faith to be authorized. We will not pursue legal action against researchers who:

- Act in good faith
- Avoid privacy violations, data destruction, and service interruption
- Report vulnerabilities promptly
- Give us reasonable time to respond before disclosure

## Security Measures

This project implements:

- **CodeQL Analysis**: Automated vulnerability scanning
- **Dependency Scanning**: Dependabot for Cargo, Mix, and GitHub Actions
- **Trivy Scanning**: Container and filesystem vulnerability detection
- **cargo-audit**: Rust-specific vulnerability checking
- **TruffleHog**: Secret detection in commits
- **OSSF Scorecard**: Supply chain security assessment

## Acknowledgments

We maintain a hall of fame for security researchers at:
https://hyperpolymath.org/security/acknowledgments
