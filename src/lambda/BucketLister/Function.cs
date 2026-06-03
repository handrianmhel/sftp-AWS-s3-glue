using System.Text.Json;
using Amazon;
using Amazon.Lambda.Core;
using Amazon.S3;
using Amazon.S3.Model;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace BucketLister;

public class Function
{
    private const int PayloadKeyCap = 100;
    private const int VerboseLogThreshold = 100;
    private const int VerboseLogInterval = 50;

    public async Task<Response> FunctionHandler(Input? input, ILambdaContext context)
    {
        var bucket = Environment.GetEnvironmentVariable("BUCKET_NAME");
        if (string.IsNullOrWhiteSpace(bucket))
        {
            var msg = "BucketLister: BUCKET_NAME environment variable is not set.";
            LambdaLogger.Log(msg);
            throw new InvalidOperationException(msg);
        }

        var prefix = input?.Prefix ?? "";
        var region = ResolveRegion(context);

        LambdaLogger.Log($"BucketLister: listing s3://{bucket}/{prefix}");

        try
        {
            using var client = new AmazonS3Client(region);
            var keys = new List<string>();
            var totalCount = 0;
            string? continuationToken = null;

            do
            {
                var response = await client.ListObjectsV2Async(new ListObjectsV2Request
                {
                    BucketName = bucket,
                    Prefix = prefix,
                    ContinuationToken = continuationToken
                });

                foreach (var obj in response.S3Objects)
                {
                    totalCount++;
                    if (totalCount <= VerboseLogThreshold ||
                        totalCount % VerboseLogInterval == 0)
                    {
                        LambdaLogger.Log($"BucketLister: {obj.Key} ({obj.Size} bytes)");
                    }

                    if (keys.Count < PayloadKeyCap)
                    {
                        keys.Add(obj.Key);
                    }
                }

                continuationToken = response.IsTruncated == true ? response.NextContinuationToken : null;
            } while (continuationToken != null);

            LambdaLogger.Log($"BucketLister: total {totalCount} object(s)");

            return new Response(bucket, prefix, totalCount, keys, totalCount > PayloadKeyCap);
        }
        catch (Exception ex)
        {
            LambdaLogger.Log($"BucketLister: error: {ex.Message}");
            throw;
        }
    }

    private static RegionEndpoint ResolveRegion(ILambdaContext context)
    {
        var regionName = Environment.GetEnvironmentVariable("AWS_REGION");
        if (string.IsNullOrWhiteSpace(regionName))
        {
            var arnParts = context.InvokedFunctionArn.Split(':');
            if (arnParts.Length > 3)
            {
                regionName = arnParts[3];
            }
        }

        if (string.IsNullOrWhiteSpace(regionName))
        {
            throw new InvalidOperationException("BucketLister: could not determine AWS region.");
        }

        return RegionEndpoint.GetBySystemName(regionName);
    }
}

public record Input(string? Prefix);

public record Response(
    string Bucket,
    string Prefix,
    int Count,
    IReadOnlyList<string> Keys,
    bool KeysTruncatedInPayload);
