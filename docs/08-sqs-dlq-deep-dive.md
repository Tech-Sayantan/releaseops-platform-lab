# SQS And DLQ Deep Dive

Last updated: 2026-07-19

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
