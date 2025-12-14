# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of Churn MLOps seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### Where to Report

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please report security vulnerabilities to:
- **Email**: security@techitfactory.com
- **Subject**: [SECURITY] Brief description of the issue

### What to Include

Please include the following information in your report:

1. **Description**: Clear description of the vulnerability
2. **Impact**: Potential impact and attack scenario
3. **Reproduction**: Step-by-step instructions to reproduce
4. **Proof of Concept**: Code, screenshots, or logs demonstrating the issue
5. **Suggested Fix**: If you have a suggestion for fixing the issue
6. **Your Contact**: How we can reach you for follow-up

### Response Timeline

- **Acknowledgment**: Within 48 hours of report submission
- **Initial Assessment**: Within 5 business days
- **Status Update**: Every 7 days until resolved
- **Fix Release**: Depends on severity (see below)

### Severity Levels

| Severity | Description | Response Time |
|----------|-------------|---------------|
| **Critical** | Remote code execution, privilege escalation | 24-48 hours |
| **High** | Data leakage, authentication bypass | 3-7 days |
| **Medium** | XSS, CSRF, information disclosure | 14-30 days |
| **Low** | Minor issues with limited impact | Best effort |

## Security Measures

### Code Security

- **Static Analysis**: Bandit for Python security linting
- **Dependency Scanning**: Safety and Snyk for vulnerability detection
- **Container Scanning**: Trivy for Docker image vulnerabilities
- **SBOM Generation**: Software Bill of Materials for all releases

### Infrastructure Security

- **Network Policies**: Restrict pod-to-pod communication
- **RBAC**: Least-privilege access control
- **Pod Security**: SecurityContext and PodSecurityPolicies
- **Secret Management**: Kubernetes secrets, sealed-secrets support
- **TLS**: Encrypted traffic via Ingress with cert-manager

### CI/CD Security

- **Signed Commits**: Encouraged for all contributions
- **Branch Protection**: Required reviews, status checks
- **Secrets Scanning**: GitHub secret scanning enabled
- **Image Signing**: Container image signing (planned)

## Security Best Practices

### For Contributors

1. **Never commit secrets** (API keys, passwords, tokens)
2. **Use environment variables** for sensitive configuration
3. **Keep dependencies updated** regularly
4. **Follow secure coding guidelines**
5. **Write security tests** for authentication/authorization

### For Deployers

1. **Change default passwords** immediately
2. **Use strong TLS certificates** (not self-signed in production)
3. **Enable pod security policies**
4. **Regularly update base images**
5. **Monitor security advisories**
6. **Implement network segmentation**
7. **Enable audit logging**
8. **Regular security assessments**

## Known Issues

Currently no known security issues. Check [GitHub Security Advisories](https://github.com/yourusername/churn-mlops-prod/security/advisories) for updates.

## Security Updates

Subscribe to security updates:
- Watch this repository for security advisories
- Join our security mailing list: security-updates@techitfactory.com

## Disclosure Policy

- **Responsible Disclosure**: 90 days after fix is available
- **Credit**: Security researchers credited in release notes
- **Coordination**: We'll work with you on disclosure timing

## Security Checklist

### Before Production Deployment

- [ ] Changed all default passwords
- [ ] Configured TLS certificates
- [ ] Enabled network policies
- [ ] Set resource limits
- [ ] Configured RBAC properly
- [ ] Removed debug/test accounts
- [ ] Enabled audit logging
- [ ] Configured backup strategy
- [ ] Tested disaster recovery
- [ ] Reviewed security scan results
- [ ] Updated dependencies
- [ ] Configured monitoring and alerts

## Compliance

This project aims to follow:
- OWASP Top 10 security practices
- CIS Kubernetes Benchmark
- NIST Cybersecurity Framework
- SOC 2 Type II controls (for hosted version)

## Security Tools

### Integrated Tools

- **Ruff**: Code linting
- **Bandit**: Security-focused Python linting
- **Safety**: Dependency vulnerability scanning
- **Trivy**: Container vulnerability scanning
- **Snyk**: Comprehensive security scanning

### Manual Testing

We recommend:
- **OWASP ZAP**: Web application security testing
- **kubectl-who-can**: RBAC auditing
- **kubesec**: Kubernetes security analysis
- **kube-bench**: CIS benchmark testing

## Contact

For non-security issues, use:
- GitHub Issues: [Report a bug](https://github.com/yourusername/churn-mlops-prod/issues/new)
- Email: support@techitfactory.com

---

**Thank you for helping keep Churn MLOps secure!**
