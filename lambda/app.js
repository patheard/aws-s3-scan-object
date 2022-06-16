"use strict";

/**
 * Lambda function that can be invoked by S3 events or SNS messages.
 * This function triggers a scan of newly created S3 objects or updates
 * the scan status of existing S3 objects based on an SNS message payload.
 */

const axios = require("axios");
const { S3Client, PutObjectTaggingCommand } = require("@aws-sdk/client-s3");
const { SSMClient, GetParameterCommand } = require("@aws-sdk/client-ssm");

const REGION = process.env.REGION;
const SCAN_FILES_URL = process.env.SCAN_FILES_URL;
const SCAN_FILES_API_KEY_PARAM_NAME = process.env.SCAN_FILES_API_KEY_PARAM_NAME;
const SCAN_IN_PROGRESS = "IN_PROGRESS";
const SCAN_FAILED_TO_START = "FAILED_TO_START";
const EVENT_S3 = "aws:s3";
const EVENT_SNS = "aws:sns";

const s3Client = new S3Client({ region: REGION });
const ssmClient = new SSMClient({ region: REGION });

/**
 * Performs function initialization outside of the Lambda handler so that
 * it only occurs once per cold start of the function rather than on
 * every invocation.
 * @returns {Promise<{apiKey: string}>} API key to use for the scan
 */
const initConfig = async () => {
  return (async () => {
    try {
      const command = new GetParameterCommand({
        Name: SCAN_FILES_API_KEY_PARAM_NAME,
        WithDecryption: true,
      });
      const response = await ssmClient.send(command);
      return { apiKey: response.Parameter.Value };
    } catch (error) {
      console.log(
        `ERROR: Unable to get '${SCAN_FILES_API_KEY_PARAM_NAME}' SSM parameter: ${error}`
      );
      return null;
    }
  })();
};

// Start config load on cold starts. This can switch to a top level `await` if we switch to ES modules:
// https://aws.amazon.com/blogs/compute/using-node-js-es-modules-and-top-level-await-in-aws-lambda/
const configPromise = initConfig();

/**
 * Lambda handler function.  This function is invoked when a new S3 object is
 * created in response to `s3:ObjectCreated:*` events or when an SNS message
 * is received with an update scan status.
 * @param {Object} event Lambda invocation event
 */
exports.handler = async (event) => {
  const config = await configPromise;
  let errorCount = 0;

  // Process all event records
  for (const record of event.Records) {
    let scanStatus = null;
    let isObjectTagged = false;
    let eventSource = getRecordEventSource(record);
    let s3Object = getS3ObjectFromRecord(eventSource, record);

    // Start a scan of the new S3 object
    if (eventSource === EVENT_S3) {
      const response = await startS3ObjectScan(
        `${SCAN_FILES_URL}/version`,
        config.apiKey,
        s3Object
      );
      scanStatus =
        response.status === 200 ? SCAN_IN_PROGRESS : SCAN_FAILED_TO_START;

      // Get the scan status for an existing S3 object
    } else if (eventSource === EVENT_SNS) {
      scanStatus = record.Sns.MessageAttributes.Result.Value;

      // Unknown event source
    } else {
      console.log(`ERROR: unsupported event source: ${JSON.stringify(record)}`);
    }

    // Tag the S3 object if we've got a scan status
    if (scanStatus !== null) {
      isObjectTagged = await tagS3Object(s3Client, s3Object, [
        { Key: "av-status", Value: scanStatus },
        { Key: "av-timestamp", Value: new Date().getTime() },
      ]);
    }

    // Track if there were any errors processing this record
    if (scanStatus === SCAN_FAILED_TO_START || isObjectTagged === false) {
      errorCount++;
    }
  }

  return {
    status: errorCount > 0 ? 422 : 200,
    body: `Event records processesed: ${event.Records.length}, Errors: ${errorCount}`,
  };
};

/**
 * Determines the event record's source service.  This is either S3 or SNS.
 * @param {Object} record Lambda invocation event record
 * @returns {String} Event record source service, or `null` if not valid
 */
const getRecordEventSource = (record) => {
  let eventSource = null;

  if (record.eventSource === EVENT_S3) {
    eventSource = EVENT_S3;
  } else if (record.EventSource === EVENT_SNS) {
    eventSource = EVENT_SNS;
  }

  return eventSource;
};

/**
 * Retrieves the S3 object's Bucket and key from the Lambda invocation event.
 * @param {String} eventSource The source of the event record
 * @param {Object} record Lambda invocation event record
 * @returns {{Bucket: string, Key: string}} S3 object bucket and key
 */
const getS3ObjectFromRecord = (eventSource, record) => {
  let s3Object = null;

  if (eventSource === EVENT_S3) {
    s3Object = {
      Bucket: record.s3.bucket.name,
      Key: decodeURIComponent(record.s3.object.key.replace(/\+/g, " ")),
    };
  } else if (eventSource === EVENT_SNS) {
    s3Object = {
      Bucket: record.Sns.MessageAttributes.Bucket.Value,
      Key: record.Sns.MessageAttributes.Key.Value,
    };
  }

  return s3Object;
};

/**
 * Starts a scan of the S3 object using the provided URL endpoint and API key.
 * @param {String} apiEndpoint API endpoint to use for the scan
 * @param {String} apiKey API authorization key to use for the scan
 * @param {{Bucket: string, Key: string}} s3Object S3 object to tag
 * @returns {Response} Axios response from the scan request
 */
const startS3ObjectScan = async (apiEndpoint, apiKey, s3Object) => {
  try {
    const response = await axios.get(apiEndpoint, {
      headers: {
        Accept: "application/json",
        Authorization: apiKey,
      },
    });
    return response;
  } catch (error) {
    console.log(
      `ERROR: failed to start scan for ${s3Object}: ${error.response}`
    );
    return error.response;
  }
};

/**
 * Tags the S3 object with the provided tags.
 * @param {S3Client} s3Client AWS SDK S3 client used to tag the object
 * @param {{Bucket: string, Key: string}} s3Object S3 object to tag
 * @param {Array<{Key: string, Value: string}>} tags Array of Key/Value pairs to tag the S3 object with
 */
const tagS3Object = async (s3Client, s3Object, tags) => {
  const tagging = {
    Tagging: {
      TagSet: tags,
    },
  };
  let isSuccess = false;

  try {
    const command = new PutObjectTaggingCommand({ ...s3Object, ...tagging });
    const response = await s3Client.send(command);
    isSuccess = response.VersionId !== undefined;
  } catch (error) {
    console.log(`ERROR: failed to tag S3 object: ${error}`);
  }

  return isSuccess;
};

// Helpers for testing
exports.helpers = {
  getRecordEventSource,
  getS3ObjectFromRecord,
  initConfig,
  startS3ObjectScan,
  tagS3Object,
};
