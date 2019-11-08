# Proxy Request Service

This is a small Ruby app deployed as an AWS Lambda behind API Gateway to serve as a proxy for arbitrary endpoints that we want to make asynchronous (i.e. because something in their implementation is synchronous/blocking/brittle). This app listens on `POST` and `PATCH` requests on any endpoint matching:

```
/api/v0.1/.*
```

## Setup

### Installation

```
bundle install; bundle install --deployment
```

### Setup

All config is in sam.[ENVIRONMENT].yml templates, encrypted as necessary.

## Contributing

### Git Workflow

 * Cut branches from `development`.
 * Create PR against `development`.
 * After review, PR author merges.
 * Merge `development` > `qa`
 * Merge `qa` > `master`
 * Tag version bump in `master`

### Running events locally

The following will invoke the lambda against the sample `event.json`:

```
sam local invoke --event event.json --region us-east-1 --template sam.[ENVIRONMENT].yml --profile nypl-digital-dev
```

Note also that if you choose `sam.local.yml`, you'll need to start SQS via Localstack as a prerequesite to above.

#### Localstack for offline testing

A sample `sam.local.yml` includes an `SQS_QUEUE_URL`, which decrypts to "http://host.docker.internal:4576/queue/proxy-request-service".

Localstack may be useful for running a local SQS to fully test the application offline (i.e. without writing events into the QA/Production SQS).

To install localstack:

**1. Install:**

`pip3 install localstack` (or use `pip` if that's what's available)

The [repo](https://github.com/localstack/localstack#installing) may offer help if you get stuck.

**2. Start the service:**

`SERVICES=sqs localstack start`

**3. Create a local queue:**

If you don't already have one, create a "local" aws profile with blank credentials:

```
[local]
aws_access_key_id =
aws_secret_access_key =
```

That will enable you to use the `aws` cli using `--profile local`, which means you guarantee you are not authenticating against any actual AWS account.

Add the queue:
```
aws sqs create-queue --region us-east-1 --queue-name proxy-request-service --endpoint http://localhost:4576 --profile local
```

When populating an SQS queue, the `aws sqs` cli tool may be useful for inspecting the messages written. For example, when populating a localstack SQS, run the following to pop the last 10 messages:

```
aws sqs receive-message --region us-east-1 --queue-url http://localhost:4576/queue/proxy-request-service --endpoint http://localhost:4576 --profile local --attribute-names All --message-attribute-names All --max-number-of-messages 10
```

#### Modifying `event.json`

Update `event.json` as follows:

```
sam local generate-event apigateway aws-proxy --path api/v0.1/checkout-request --method POST --body "{ \"itemBarcode\": \"01234567891011\", \"patronBarcode\": \"10119876543210\", \"owningInstitutionId\": \"NYPL\", \"desiredDueDate\": \"2020-03-19T04:00:00Z\" }" > event.json
```

### Running server locally

To run the server locally using a SAM template with a configured API Gateway event:

```
sam local start-api --region us-east-1 --template sam.local-with-api-gateway.yml --profile [aws profile]
```

### Gemfile Changes

Given that gems are installed with the `--deployment` flag, Bundler will complain if you make changes to the Gemfile. To make changes to the Gemfile, exit deployment mode:

```
bundle install --no-deployment
```

## Testing

```
bundle exec rspec
```

## Deploy

Deployments are entirely handled by Travis-ci.com. To deploy to development, qa, or production, commit code to the `development`, `qa`, and `master` branches on origin, respectively.

### Manual deployments

If for some reason you need to skip Travis, the following models manually deploying QA:

To package for QA:

```
sam package --region us-east-1 --template-file sam.qa.yml --output-template-file packaged-template.yaml --profile nypl-digital-dev --s3-bucket nypl-travis-builds-qa
```

To deploy to QA:

```
aws cloudformation deploy --template-file packaged-template.yaml --stack-name proxy-request-service-qa --profile nypl-digital-dev --region us-east-1 --capabilities CAPABILITY_IAM
```
