# SQS And DLQ Deep Dive

Last updated: 2026-07-18

## What We Built

We created a reusable Terraform module for Amazon SQS and connected it to the
dev environment.

Current queues:

```text
releaseops-dev-deployment-events
releaseops-dev-deployment-events-dlq
```

Terraform resources:

```text
module.sqs.aws_sqs_queue.main
module.sqs.aws_sqs_queue.dlq
```

The main queue is for normal deployment-event messages. The DLQ is where failed
messages go after repeated processing failures.

## Sleepy Revision Path

If you are reading this before an interview and your brain is tired, read in
this order:

1. Read `What SQS Is`.
2. Read `What DLQ Is`.
3. Read `Visibility Timeout`.
4. Read `At-Least-Once Delivery`.
5. Read `Terraform Walkthrough`.
6. Read `Common Production Issues`.
7. Read `Interview Questions To Practice`.

Do not try to memorize every Terraform line first. First understand the story:

```text
API should not do slow work directly.
API sends a message to SQS.
Worker reads the message later.
If worker fails repeatedly, message goes to DLQ.
Engineer investigates DLQ.
```

That is the heart of this topic.

## One-Minute Mental Model

Imagine a restaurant.

The customer gives an order to the cashier. The cashier does not cook the food.
The cashier writes the order and passes it to the kitchen. The kitchen prepares
the food in the background.

In our system:

```text
customer      = user
cashier       = api service
order slip    = SQS message
kitchen queue = SQS queue
cook          = worker service
bad order box = DLQ
```

If the order slip is unreadable or impossible to process, it should not block
all other orders. It goes into a separate place for investigation. That separate
place is the DLQ.

## What SQS Is

SQS means Simple Queue Service.

It is AWS's managed message queue service. A queue is a waiting room for work.
One service puts a message into the queue, and another service reads that
message later.

In our ReleaseOps platform, the future flow will look like this:

```text
api service receives a deployment request
api service writes request data to PostgreSQL
api service sends a message to SQS
worker service reads the message from SQS
worker service performs background deployment work
```

This keeps the API fast. The API should not hold the user's HTTP request open
while slow background work happens.

The key DevOps idea is called **decoupling**.

Without SQS:

```text
api service directly depends on worker-speed work
if deployment work is slow, API becomes slow
if deployment work fails, user request may fail
```

With SQS:

```text
api service only needs to save the request and send a message
worker service can process the work independently
temporary worker failure does not immediately break the API
```

This is one reason queues are common in production systems.

Bad design:

```text
user clicks approve
api starts slow deployment work
user waits
request times out
```

Better design:

```text
user clicks approve
api accepts request
api sends message to SQS
worker handles slow work in the background
```

## What A Message Is

An SQS message is a small piece of data that describes work to be done.

Future example:

```json
{
  "deploymentId": "dep-123",
  "service": "api",
  "environment": "dev",
  "requestedBy": "tan",
  "action": "deploy"
}
```

The queue does not understand the business meaning of the message. It only
stores and delivers it. The application code decides what the message means.

Important: SQS is not a database.

SQS is for passing work from one component to another. The real source of truth
should still be in a database or another durable system.

For our future app:

```text
PostgreSQL stores deployment request details.
SQS carries a small event saying "process deployment dep-123".
```

That design is safer than putting the entire business state only inside the
queue message.

## What DLQ Is

DLQ means Dead Letter Queue.

It stores messages that failed too many times.

Example:

```text
worker receives message
worker fails
message becomes visible again
worker receives message again
worker fails again
after max_receive_count attempts, message moves to DLQ
```

Why this matters:

- failed messages are not lost silently
- broken messages stop blocking normal processing
- engineers get a place to inspect failures
- alerts can be created when DLQ has messages

Interview line:

> A DLQ is a safety mechanism for failed asynchronous work. If a message cannot
> be processed after several retries, it moves to the DLQ for investigation
> instead of retrying forever or disappearing silently.

## Main Queue Vs DLQ

Main queue:

```text
normal messages
worker reads from here
expected to be mostly empty or moving
```

DLQ:

```text
failed messages
engineers inspect this
should normally be empty
```

If the DLQ has messages, it usually means something needs attention.

## Standard Queue Vs FIFO Queue

AWS SQS has two major queue types:

- Standard queue
- FIFO queue

We are using the default standard queue.

Standard queue:

```text
very high throughput
at-least-once delivery
best-effort ordering
duplicates are possible
```

FIFO queue:

```text
first-in-first-out ordering
deduplication support
lower throughput than standard queue
queue name must end with .fifo
```

Why standard queue is okay for our lab:

Our future worker should process deployment messages using a unique
`deploymentId`. If a message is delivered twice, the worker can check whether
that deployment was already processed. That makes standard queue acceptable.

Interview line:

> I choose standard SQS when high throughput and loose ordering are acceptable,
> and I handle duplicate messages with idempotency. I choose FIFO when strict
> ordering or deduplication is a hard requirement.

## Visibility Timeout

Visibility timeout controls how long a message stays hidden after a worker
receives it.

Important rule:

```text
receiving a message does not delete it
```

Normal successful flow:

```text
worker receives message
message becomes invisible
worker processes message
worker deletes message
```

Failure flow:

```text
worker receives message
message becomes invisible
worker crashes
worker does not delete message
visibility timeout expires
message becomes visible again
another worker can retry it
```

Production gotcha:

If the visibility timeout is too short, the same message can be processed by
two workers at the same time.

Example:

```text
job normally takes 3 minutes
visibility timeout is 60 seconds
worker A starts processing
after 60 seconds message becomes visible again
worker B also starts processing the same message
```

Fix:

- set visibility timeout longer than normal processing time
- make worker code idempotent
- extend visibility timeout from application code for long-running jobs

## Message Retention

Message retention controls how long SQS keeps messages that are not deleted.

If the worker is down, messages can wait in the queue.

Example:

```text
worker deployment fails
api keeps sending messages
messages wait in SQS
worker comes back
worker starts processing backlog
```

AWS allows retention from 1 minute to 14 days.

Production gotcha:

SQS is not permanent storage. If a message sits longer than the retention
period, SQS deletes it.

## Max Receive Count

`max_receive_count` controls how many times a message can fail before moving
to the DLQ.

Example with `max_receive_count = 5`:

```text
receive 1 -> fail
receive 2 -> fail
receive 3 -> fail
receive 4 -> fail
receive 5 -> fail
move to DLQ
```

This protects the system from poison messages.

A poison message is a message that will never succeed because the data is bad
or the code cannot handle it.

Example:

```json
{
  "deploymentId": null
}
```

If the worker requires `deploymentId`, this message may fail forever. DLQ moves
it aside after repeated failures.

## Redrive Policy

The redrive policy connects the main queue to the DLQ.

In Terraform:

```hcl
redrive_policy = jsonencode({
  deadLetterTargetArn = aws_sqs_queue.dlq.arn
  maxReceiveCount     = var.max_receive_count
})
```

Meaning:

```text
If a message fails too many times,
send it to this DLQ.
```

`deadLetterTargetArn` tells SQS where failed messages should go.

`maxReceiveCount` tells SQS how many receive attempts are allowed first.

## Why We Used `jsonencode`

AWS expects the redrive policy as JSON.

Instead of writing a raw JSON string manually, we used:

```hcl
jsonencode({
  deadLetterTargetArn = aws_sqs_queue.dlq.arn
  maxReceiveCount     = var.max_receive_count
})
```

This is safer because Terraform handles JSON formatting and escaping.

Bad manual style:

```hcl
"{\"maxReceiveCount\":5}"
```

Good Terraform style:

```hcl
jsonencode({
  maxReceiveCount = 5
})
```

Interview line:

> I prefer `jsonencode` for JSON policies in Terraform because it reduces
> quoting mistakes and keeps the code easier to review.

## At-Least-Once Delivery

SQS standard queues use at-least-once delivery.

That means:

```text
a message will be delivered at least once
but it may be delivered more than once
```

This is extremely important.

Application code must be idempotent.

Idempotent means:

```text
processing the same message twice should not create a wrong final result
```

Bad example:

```text
charge customer
```

If the message runs twice, the customer may be charged twice.

Safer example:

```text
check if deploymentId was already processed
if already processed, skip
if not processed, continue
```

For our future worker service, we should design around a unique
`deploymentId`.

## Terraform Walkthrough

This section explains every important Terraform piece we wrote.

### Module Variables

File:

```text
infra/modules/sqs/variables.tf
```

### `name_prefix`

```hcl
variable "name_prefix" {
  description = "Name prefix used for SQS resources."
  type        = string
}
```

This gives every queue a consistent project/environment prefix.

For us:

```text
project_name = releaseops
environment  = dev
name_prefix  = releaseops-dev
```

Production reason:

In a real AWS account, there may be hundreds or thousands of resources. Names
like `queue1` or `test` are useless. Names like
`releaseops-dev-deployment-events` tell you what the resource belongs to.

### `queue_name`

```hcl
variable "queue_name" {
  description = "Logical name of the main SQS queue."
  type        = string
}
```

This is the business name of the queue.

For us:

```text
deployment-events
```

The final queue name becomes:

```text
releaseops-dev-deployment-events
```

We keep this as a variable because the module should be reusable. The same
module could later create:

```text
releaseops-dev-email-events
releaseops-dev-audit-events
releaseops-dev-report-jobs
```

### `visibility_timeout_seconds`

```hcl
variable "visibility_timeout_seconds" {
  description = "How long a message stays invisible after a worker receives it."
  type        = number
  default     = 60
}
```

This is the worker processing window.

If the worker receives a message, SQS hides that message for 60 seconds. During
those 60 seconds, another worker should not receive the same message.

If the worker finishes successfully, it deletes the message.

If the worker crashes, the message becomes visible again after 60 seconds.

### `message_retention_seconds`

```hcl
variable "message_retention_seconds" {
  description = "How long SQS keeps messages if they are not deleted."
  type        = number
  default     = 345600
}
```

`345600` seconds means 4 days.

This means unprocessed messages can wait in the queue for up to 4 days.

Why useful:

If the worker is down for a short period, messages wait instead of disappearing.

Why dangerous if misunderstood:

SQS is not long-term storage. After the retention window, old messages are
deleted.

### `max_receive_count`

```hcl
variable "max_receive_count" {
  description = "How many times a message can fail before moving to the DLQ."
  type        = number
  default     = 5
}
```

This controls DLQ movement.

If the same message is received 5 times and still not processed successfully,
SQS moves it to the DLQ.

This protects the worker from retrying a broken message forever.

### `tags`

```hcl
variable "tags" {
  description = "Common tags to apply to SQS resources."
  type        = map(string)
  default     = {}
}
```

Tags are metadata.

For us:

```text
Project     = releaseops
Environment = dev
Owner       = tan
ManagedBy   = terraform
```

Real teams use tags for:

- cost tracking
- ownership
- cleanup
- security reporting
- automation

### Validation Blocks

Example:

```hcl
validation {
  condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
  error_message = "max_receive_count must be between 1 and 1000."
}
```

Validation blocks make Terraform fail early with a clear message.

Without validation, bad input may fail later with a confusing AWS API error.

Interview line:

> I like adding validation to module inputs because it catches bad values during
> plan time and makes the module safer for other engineers.

### DLQ Resource

File:

```text
infra/modules/sqs/main.tf
```

```hcl
resource "aws_sqs_queue" "dlq" {
  name = "${var.name_prefix}-${var.queue_name}-dlq"

  message_retention_seconds = var.message_retention_seconds

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-${var.queue_name}-dlq"
    Component = "sqs"
    QueueType = "dead-letter"
  })
}
```

This creates the dead-letter queue.

Important fields:

`name`:

```text
releaseops-dev-deployment-events-dlq
```

`message_retention_seconds`:

how long failed messages stay available for inspection.

`tags`:

common tags plus `Component=sqs` and `QueueType=dead-letter`.

### Main Queue Resource

```hcl
resource "aws_sqs_queue" "main" {
  name = "${var.name_prefix}-${var.queue_name}"

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-${var.queue_name}"
    Component = "sqs"
    QueueType = "main"
  })
}
```

This creates the main queue.

Important fields:

`name`:

```text
releaseops-dev-deployment-events
```

`visibility_timeout_seconds`:

how long the message is hidden after worker receives it.

`message_retention_seconds`:

how long SQS keeps unprocessed messages.

`redrive_policy`:

connects main queue to DLQ.

`tags`:

common tags plus `Component=sqs` and `QueueType=main`.

### Terraform Dependency

The main queue uses:

```hcl
aws_sqs_queue.dlq.arn
```

Because of this reference, Terraform automatically understands:

```text
create DLQ first
then create main queue
```

We do not need `depends_on`.

Interview line:

> In Terraform, direct references usually create the dependency graph
> automatically. I avoid `depends_on` unless Terraform cannot infer the
> dependency from expressions.

### Root Module Wiring

File:

```text
infra/envs/dev/main.tf
```

```hcl
module "sqs" {
  source = "../../modules/sqs"

  name_prefix = "${var.project_name}-${var.environment}"
  queue_name  = var.deployment_queue_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}
```

This is where the generic module becomes a real dev environment resource.

The module does not know about `project_name` or `environment`. The root module
passes the final values into it.

The data flow is:

```text
terraform.tfvars
  -> root variable deployment_queue_name
  -> module "sqs"
  -> var.queue_name inside SQS module
  -> aws_sqs_queue resources
```

## Terraform Plan We Expected

When we ran plan from:

```text
infra/envs/dev
```

we expected:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Why 2?

```text
1 main queue
1 DLQ
```

If Terraform had shown a VPC, subnet, RDS, or ECR replacement, that would have
been a red flag.

Interview line:

> I do not only check the summary count. I also inspect what resources are
> being changed, especially any destroy or replacement action.

## Mistake We Hit: Running Plan Inside The Module

At one point, `terraform plan` was run from:

```text
infra/modules/sqs
```

Terraform then asked for:

```text
var.name_prefix
```

That happened because a reusable module folder does not have the environment
values.

Correct path:

```text
infra/envs/dev
```

Rule:

```text
modules folder = reusable building blocks
envs/dev folder = actual deployable root module
```

This is a very common beginner Terraform confusion and a very useful interview
lesson.

## Queue URL Vs Queue ARN

The module exposes both URL and ARN.

Queue URL:

```text
application uses this to send and receive messages
```

Queue ARN:

```text
IAM policies and monitoring use this
```

Example:

```text
api service needs SendMessage permission on queue ARN
worker service needs ReceiveMessage and DeleteMessage permission on queue ARN
application configuration may use the queue URL
```

Interview line:

> I expose the queue URL for application configuration and the queue ARN for IAM
> permissions and monitoring.

## Common Production Issues

### Messages Are Stuck In The Main Queue

Possible causes:

- worker is not running
- worker has no IAM permission to read messages
- worker points to the wrong queue URL
- messages take too long to process
- visibility timeout is too short

Debug path:

1. Check queue depth.
2. Check worker logs.
3. Check IAM permissions.
4. Check queue URL.
5. Check visibility timeout and processing time.

### Messages Are Going To DLQ

Possible causes:

- message schema is invalid
- worker code has a bug
- downstream dependency is failing
- IAM permission is missing
- message processing is not idempotent

Debug path:

1. Inspect DLQ message body.
2. Find the failure in worker logs.
3. Fix the root cause.
4. Redrive or replay messages only after the fix.

### Duplicate Processing Happens

Possible causes:

- normal SQS at-least-once delivery
- visibility timeout too short
- worker crashes after completing work but before deleting message

Fix path:

1. Use idempotency keys.
2. Store processed message/deployment IDs.
3. Set visibility timeout properly.
4. Delete messages only after successful processing.

### Queue Cost Or Noise Grows

Possible causes:

- worker is broken
- messages are never deleted
- retry loop is too aggressive
- no monitoring on queue depth

Fix path:

1. Add CloudWatch alarms.
2. Monitor main queue age and DLQ depth.
3. Fix worker delete logic.
4. Review retry and retention settings.

## Interview Questions To Practice

### Why use SQS?

To decouple services and move slow or unreliable work into background
processing.

### Why use a DLQ?

To capture messages that repeatedly fail so they are not lost silently and do
not retry forever.

### What is visibility timeout?

The time a message stays hidden after a worker receives it. If the worker does
not delete the message before the timeout expires, the message becomes visible
again.

### Does SQS guarantee exactly-once delivery?

Standard SQS does not guarantee exactly-once delivery. It provides at-least-once
delivery, so applications must handle duplicate messages safely.

### What should you monitor?

Important metrics:

- visible messages in main queue
- oldest message age
- messages in DLQ
- worker errors
- processing latency

DLQ message count should normally be zero. If it is not zero, someone should
investigate.

## Verification Commands

Run from:

```text
/Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab/infra/envs/dev
```

```bash
terraform state list | grep sqs
terraform output | grep deployment
terraform plan | grep "No changes"
```

Expected state resources:

```text
module.sqs.aws_sqs_queue.dlq
module.sqs.aws_sqs_queue.main
```

Expected plan result:

```text
No changes. Your infrastructure matches the configuration.
```
