"use strict";

/**
 * Lambda function that is invoked when an S3 object is created in a bucket.
 * This function triggers a scan of the new object for malicious content
 * and updates the object's tag with the scan status.
 */

const axios = require('axios');
const { S3Client, PutObjectTaggingCommand } = require("@aws-sdk/client-s3");
const { SSMClient, GetParameterCommand } = require("@aws-sdk/client-ssm");

const REGION = process.env.REGION;
const SCAN_FILES_URL = process.env.SCAN_FILES_URL;
const SCAN_FILES_API_KEY_PARAM_NAME = process.env.SCAN_FILES_API_KEY_PARAM_NAME;;

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
    console.log(`Loading SSM parameter '${SCAN_FILES_API_KEY_PARAM_NAME}'`);
    const command = new GetParameterCommand({
      Name: SCAN_FILES_API_KEY_PARAM_NAME,
      WithDecryption: true
    });
    const response = await ssmClient.send(command);
    return { apiKey: response.Parameter.Value };
  })();
};

// Start config load on cold starts. This can switch to a top level `await` if we switch to ES modules:
// https://aws.amazon.com/blogs/compute/using-node-js-es-modules-and-top-level-await-in-aws-lambda/
const configPromise = initConfig(); 

/**
 * Lambda handler function.  This function is invoked when a new S3 object is
 * created in response to `s3:ObjectCreated:*` events.  It downloads the object
 * and triggers a scan for malicious content.
 * @param {Object} event Lambda invocation event
 */
exports.handler = async(event) => {
  const config = await configPromise;
  const s3Object = getS3ObjectFromEvent(event);

  const response = await startS3ObjectScan(`${SCAN_FILES_URL}/version`, config.apiKey, s3Object);
  const scanStatus = response.status === 200 ? "IN_PROGRESS" : "FAILED_TO_START";
  await tagS3Object(s3Client, s3Object, [{ Key: "scan_status", Value: scanStatus }]);

  return { 
    "status": response.status,
    "body": `Scan status: ${scanStatus}`
  }
}

/**
 * Retrieves the S3 object's Bucket and key from the Lambda invocation event.
 * @param {Object} event Lambda invocation event
 * @returns {{Bucket: string, Key: string}} S3 object bucket and key
 */
 const getS3ObjectFromEvent = (event) => {
  return {
    Bucket: event.Records[0].s3.bucket.name,
    Key: decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' ')),
  };
}

/**
 * Starts a scan of the S3 object using the provided URL endpoint and API key.
 * @param {String} apiEndpoint API endpoint to use for the scan 
 * @param {String} apiKey API authorization key to use for the scan
 * @param {{Bucket: string, Key: string}} s3Object S3 object to tag
 * @returns {Response} Axios response from the scan request
 */
const startS3ObjectScan = async (apiEndpoint, apiKey, s3Object) => {
  try {
    const response = await axios.get(
      apiEndpoint, {
      headers: {
        "Accept": "application/json",
        "Authorization": apiKey
      }
    });
    return response;
  } catch (error) {
    console.log(`Failed to start scan: ${error.response}`);
    return error.response;
  }
}

/**
 * Tags the S3 object with the provided tags.
 * @param {S3Client} s3Client AWS SDK S3 client used to tag the object
 * @param {{Bucket: string, Key: string}} s3Object S3 object to tag
 * @param {Array<{Key: string, Value: string}>} tags Array of Key/Value pairs to tag the S3 object with
 */
 const tagS3Object = async (s3Client, s3Object, tags) => {
  const tagging = {
    "Tagging": {
      "TagSet": tags
    }
  }
  try {
    const command = new PutObjectTaggingCommand({...s3Object, ...tagging});
    await s3Client.send(command);
  } catch(error) {
    console.log(`Failed to tag S3 object: ${error}`);
  }
}
