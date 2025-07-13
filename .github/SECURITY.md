# Security Policy

## Supported Versions

We actively support the following versions of rails-openapi-gen:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability in rails-openapi-gen, please follow these steps:

### 1. Do NOT create a public issue

Please do not create a public GitHub issue for security vulnerabilities, as this could put users at risk.

### 2. Send a private report

Instead, please send an email to [security email] with the following information:

- A description of the vulnerability
- Steps to reproduce the issue
- Potential impact of the vulnerability
- Any suggested fixes or mitigations

### 3. Response timeline

We will respond to security reports within:
- **24 hours**: Initial acknowledgment of your report
- **7 days**: Detailed response with our assessment and planned timeline
- **30 days**: Security fix released (if vulnerability is confirmed)

### 4. Disclosure process

- We will work with you to understand and resolve the issue
- Once fixed, we will coordinate the disclosure timeline
- We will credit you in the security advisory (unless you prefer to remain anonymous)

## Security best practices

When using rails-openapi-gen:

1. **Keep your dependencies updated**: Regularly update the gem and its dependencies
2. **Review generated output**: Always review generated OpenAPI specifications before deployment
3. **Limit access**: Restrict access to generated OpenAPI documentation in production
4. **Validate inputs**: Ensure your Jbuilder templates and comments are properly validated

## Scope

This security policy covers:
- The rails-openapi-gen gem itself
- Generated OpenAPI specifications
- Template parsing and AST processing
- File system operations

This policy does not cover:
- Security issues in Rails applications using the gem
- Third-party dependencies (report these to the respective projects)
- Issues in the generated documentation tools (e.g., Swagger UI)

Thank you for helping keep rails-openapi-gen and its users safe!