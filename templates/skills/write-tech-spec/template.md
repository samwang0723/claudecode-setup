# Tech Spec: {{TITLE}}

| Items         | Details                                     |
| ------------- | ------------------------------------------- |
| Owner Team    | {{TEAM}}                                    |
| Feature Label | {{FEATURE_LABEL}}                           |
| Authors       | {{AUTHORS}}                                 |
| Audiences     | {{AUDIENCES}}                               |
| Status        | **Draft** / In Review / Approved / Rejected |
| Version       | V1.0 as of {{DATE}}                         |
| Reviewers     | {{REVIEWERS}}                               |
| Useful links  | {{LINKS}}                                   |
| Approved Date | -                                           |

> The TechSpec document is used mainly to describe the technical design for building services or new features, or making a big change to existing services or features.
> We suggest to follow the DDD (Domain Driven Design) approach to do our technical design works.

---

## TL;DR Change Summary

{{SUMMARY}}

---

## 1. Background

### 1.1 Objective

{{OBJECTIVE}}

### 1.2 Goals

{{GOALS}}

### 1.3 Non-Goals

{{NON_GOALS}}

---

## 2. Architecture Overview

{{ARCHITECTURE_DIAGRAM}}

### 2.1 Service Relationship

| Service       | Relationship        | Purpose       |
| ------------- | ------------------- | ------------- |
| {{SERVICE_1}} | Upstream/Downstream | {{PURPOSE_1}} |

---

## 3. Domain Design

### 3.1 Use Cases

{{USE_CASES}}

### 3.2 Fund Flow Diagrams

> Include fund flow diagrams if financial transactions are involved.

{{FUND_FLOW}}

### 3.3 Domain Models Design

{{DOMAIN_MODELS}}

> **Note:** If any transaction features involved, register the new transaction kind on #main-app\_\_new-transaction-kind

### 3.4 State Machines Design

{{STATE_MACHINES}}

### 3.5 Configuration Design

| Setting/Flag  | Type    | Default | Description   |
| ------------- | ------- | ------- | ------------- |
| {{FLAG_NAME}} | boolean | false   | {{FLAG_DESC}} |

---

## 4. Data Design

### 4.1 DB Schemas Design

{{ER_DIAGRAM}}

### 4.2 Database Design

{{DATABASE_DESIGN}}

### 4.3 Storage Design

{{STORAGE_DESIGN}}

### 4.4 Data Privacy Design

{{PRIVACY_DESIGN}}

### 4.5 Data Retention / Housekeeping Strategy

{{RETENTION_STRATEGY}}

---

## 5. APIs Design

### 5.1 Model Definition

{{MODEL_DEFINITION}}

### 5.2 User APIs - Schema

{{USER_APIS}}

#### 5.2.1 Sequence Diagrams

{{SEQUENCE_DIAGRAMS}}

#### 5.2.2 Idempotent Mechanism

{{IDEMPOTENT}}

#### 5.2.3 Rate Limit Mechanism

{{RATE_LIMIT}}

#### 5.2.4 Cache Mechanism

{{CACHE}}

#### 5.2.5 Error Responses

| Error Code                | Message     | Description  |
| ------------------------- | ----------- | ------------ |
| {{APP_CODE}}-{{ERR_CODE}} | {{ERR_MSG}} | {{ERR_DESC}} |

#### 5.2.6 Timeout Mechanism

{{TIMEOUT}}

#### 5.2.7 Retry Mechanism

{{RETRY}}

### 5.3 Internal APIs - Schema

{{INTERNAL_APIS}}

### 5.4 Partner APIs - Schema

{{PARTNER_APIS}}

---

## 6. Logging Design

{{LOGGING_DESIGN}}

> ⚠️ Data privacy consideration: Ensure PII is properly masked in logs.

---

## 7. Security Design

{{SECURITY_DESIGN}}

- [ ] Authentication/Authorization
- [ ] XSS Prevention
- [ ] CSRF Protection
- [ ] CORS Configuration
- [ ] SQL Injection Prevention
- [ ] Key Management

---

## 8. Compatibility Design

{{COMPATIBILITY}}

---

## 9. Operations

### 9.1 Capacity Planning

{{CAPACITY}}

### 9.2 Rollout Plan ⚠️ REQUIRED

{{ROLLOUT_PLAN}}

### 9.3 Monitoring Metrics and Alerts ⚠️ REQUIRED

| Metric     | Threshold     | Alert     |
| ---------- | ------------- | --------- |
| {{METRIC}} | {{THRESHOLD}} | {{ALERT}} |

### 9.4 Fallback Plan ⚠️ REQUIRED

{{FALLBACK}}

### 9.5 Security Assessment ⚠️ REQUIRED

- [ ] Threat modeling completed
- [ ] Penetration testing (if external exposure)
- [ ] Security team sign-off

### 9.6 Test Plan

{{TEST_PLAN}}

### 9.7 Infrastructure Plan

{{INFRA_PLAN}}

---

## Appendix

### References
