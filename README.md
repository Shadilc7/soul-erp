# Soul ERP

Soul ERP is a multi-tenant training and assessment platform built with Rails 8. It supports institute-level operations for training programs, attendance, assignments, participant responses, analytics, feedback, and certificate generation.

The app is role-driven and provides dedicated portals for:
- Master Admin
- Institute Admin
- Trainer
- Participant

## Key Features

- Multi-institute management with institute-specific data isolation.
- Role-based login and portal routing using Devise.
- Participant onboarding with approval workflow.
- Training program lifecycle management (individual and section-based).
- Daily attendance marking, editing, history, and CSV exports.
- Question bank and reusable question sets.
- Assignment scheduling by participant or section.
- Participant assignment submission tracking (date-based).
- Feedback workflows tied to attendance participation.
- Reporting dashboards with charts and CSV/PDF exports.
- Certificate configuration, individual/section certificate generation, publishing, and download.

## Role-Based Access

| Role | Main Capabilities |
| --- | --- |
| `master_admin` | Manage institutes and institute admins, view global dashboards, review responses, impersonate institute context |
| `institute_admin` | Manage trainers, participants, sections, training programs, questions, question sets, assignments, attendance, reports, certificates |
| `trainer` | Manage own training programs, mark attendance, export attendance reports, view feedback |
| `participant` | View assigned work by date, submit assignment responses, submit training feedback, view/download published certificates |

## Tech Stack

- Ruby `3.3.5`
- Rails `8.0.x`
- PostgreSQL (`pg` gem)
- Devise authentication
- Hotwire (Turbo + Stimulus)
- Importmap
- Bootstrap 5 + Bootstrap Icons (CDN + importmap)
- Chart.js (CDN)
- Prawn / Prawn Table / CombinePDF (PDF generation)
- Kaminari (pagination)
- Simple Calendar
- Solid Queue / Solid Cache / Solid Cable
- Kamal + Docker deployment support

## Domain Overview

Core entities in the data model:
- `Institute`, `User`, `Section`
- `Trainer`, `Participant`, `Guardian`
- `TrainingProgram`, `TrainingProgramParticipant`, `TrainingProgramSection`
- `Attendance`, `TrainingProgramFeedback`
- `Question`, `Option`, `QuestionSet`, `QuestionSetItem`
- `Assignment`, `AssignmentQuestion`, `AssignmentQuestionSet`, `AssignmentParticipant`, `AssignmentSection`
- `AssignmentResponse`, `AssignmentResponseLog`
- `CertificateConfiguration`, `IndividualCertificate`

## Local Setup

### 1. Prerequisites

- Ruby `3.3.5`
- Bundler
- PostgreSQL running locally

### 2. Install dependencies

```bash
bundle install
```

### 3. Configure database

`config/database.yml` is present in this repository and currently configured for PostgreSQL.
Update username/password/database values as needed for your machine.

### 4. Setup and run

```bash
bin/setup
```

This installs gems, prepares the database, clears logs/tmp, and starts the app.

If you only want DB setup:

```bash
bin/rails db:prepare
```

### 5. Start server

```bash
bin/dev
```

App runs at: `http://localhost:3000`

### 6. Seed initial data (recommended)

```bash
bin/rails db:seed
```

## Seeded Admin Account

`db/seeds.rb` creates a master admin when no users exist:
- Email: `masteradmin@example.com`
- Password: `admin123`

Change this password immediately in non-local environments.

## Authentication & Routing Notes

- Login path: `/login`
- Logout path: `/logout`
- Registration path: `/register`
- Root (`/`) redirects signed-in users to their role portal.

Primary route namespaces:
- `/admin`
- `/institute_admin`
- `/trainer_portal`
- `/participant_portal`

## Common Commands

```bash
# Run test suite
bin/rails test

# Lint
bin/rubocop

# Security scan
bin/brakeman

# Rails console
bin/rails console

# DB migrate
bin/rails db:migrate
```

## Production Configuration

Important environment variables used by the app/config:

- `DATABASE_URL`
- `RAILS_MASTER_KEY`
- `APP_HOST`
- `DEFAULT_URL_PROTOCOL` (default: `https`)
- `RAILS_LOG_LEVEL` (default: `info`)
- `ACTIVE_STORAGE_SERVICE` (default: `local`, optional: `amazon`)
- `ASSUME_SSL` (default: `true`)
- `FORCE_SSL` (default: `true`)
- `PORT`
- `RAILS_MAX_THREADS`
- `JOB_CONCURRENCY`


## Reporting & Certificate Capabilities

Institute Admin reporting includes:
- Assignment submission reports
- Feedback reports (section and individual)
- CSV/PDF exports
- Certificate stats and certificate lifecycle operations

Certificate lifecycle supports:
- Configuration templates
- Individual and bulk (section) generation
- Publish/unpublish
- Regeneration
- On-demand view/download

## Development Notes

- The app uses role-based layout templates and Stimulus controllers for portal interactions.
- Charts are rendered with Chart.js loaded from CDN.
- Attendance, response, and feedback workflows enforce uniqueness and date-based constraints at model level.
