using System.Text;
using System.Text.Json;
using Amazon;
using Amazon.Lambda.Core;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.SimpleSystemsManagement;
using Amazon.SimpleSystemsManagement.Model;
using Renci.SshNet;
using Renci.SshNet.Sftp;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace SftpPullIngest;

public class Function
{
    public async Task<Response> FunctionHandler(Input? input, ILambdaContext context)
    {
        var bucket = RequireEnv("BUCKET_NAME");
        var s3Prefix = NormalizePrefix(Environment.GetEnvironmentVariable("S3_PREFIX") ?? "raw/");
        var remotePath = Environment.GetEnvironmentVariable("REMOTE_PATH") ?? "/incoming";
        var maxFileBytes = ParseLongEnv("MAX_FILE_BYTES", 104_857_600);
        var ssmPrefix = NormalizeSsmPrefix(Environment.GetEnvironmentVariable("SSM_PREFIX") ?? "/sftp-pull");

        var region = ResolveRegion(context);
        var processed = 0;
        var skipped = 0;
        var errors = new List<string>();

        LambdaLogger.Log(
            $"SftpPullIngest: start bucket={bucket} prefix={s3Prefix} remote={remotePath} maxBytes={maxFileBytes}");

        SftpConnectionConfig connection;
        try
        {
            connection = await LoadConnectionConfigAsync(ssmPrefix, region);
        }
        catch (Exception ex)
        {
            var msg = $"SftpPullIngest: failed to load SSM config: {ex.Message}";
            LambdaLogger.Log(msg);
            throw new InvalidOperationException(msg, ex);
        }

        using var s3 = new AmazonS3Client(region);

        try
        {
            using var sftp = CreateSftpClient(connection);
            sftp.Connect();
            LambdaLogger.Log($"SftpPullIngest: connected to {connection.Host}:{connection.Port} as {connection.Username}");

            var entries = sftp.ListDirectory(remotePath)
                .Where(e => !e.IsDirectory && !e.IsSymbolicLink)
                .Where(e => e.Name is not "." and not "..")
                .ToList();

            LambdaLogger.Log($"SftpPullIngest: found {entries.Count} file(s) under {remotePath}");

            foreach (var entry in entries)
            {
                var fileName = entry.Name;
                try
                {
                    if (ShouldSkipFileName(fileName))
                    {
                        LambdaLogger.Log($"SftpPullIngest: skip partial/temp {fileName}");
                        skipped++;
                        continue;
                    }

                    var size = entry.Attributes.Size;
                    if (size > maxFileBytes)
                    {
                        LambdaLogger.Log($"SftpPullIngest: skip oversized {fileName} ({size} bytes > {maxFileBytes})");
                        skipped++;
                        continue;
                    }

                    var s3Key = $"{s3Prefix}{fileName}";
                    if (await ObjectExistsAsync(s3, bucket, s3Key))
                    {
                        LambdaLogger.Log($"SftpPullIngest: skip existing s3://{bucket}/{s3Key}");
                        skipped++;
                        continue;
                    }

                    await using var remoteStream = sftp.OpenRead(entry.FullName);
                    await s3.PutObjectAsync(new PutObjectRequest
                    {
                        BucketName = bucket,
                        Key = s3Key,
                        InputStream = remoteStream,
                        AutoCloseStream = false
                    });

                    LambdaLogger.Log($"SftpPullIngest: uploaded s3://{bucket}/{s3Key} ({size} bytes)");
                    processed++;
                }
                catch (Exception ex)
                {
                    var err = $"{fileName}: {ex.Message}";
                    LambdaLogger.Log($"SftpPullIngest: error {err}");
                    errors.Add(err);
                }
            }

            sftp.Disconnect();
        }
        catch (Exception ex)
        {
            var msg = $"SftpPullIngest: SFTP session failed: {ex.Message}";
            LambdaLogger.Log(msg);
            throw new InvalidOperationException(msg, ex);
        }

        LambdaLogger.Log($"SftpPullIngest: done processed={processed} skipped={skipped} errors={errors.Count}");
        return new Response(processed, skipped, errors);
    }

    private static bool ShouldSkipFileName(string fileName)
    {
        return fileName.StartsWith('.') ||
               fileName.EndsWith(".part", StringComparison.OrdinalIgnoreCase) ||
               fileName.EndsWith(".tmp", StringComparison.OrdinalIgnoreCase);
    }

    private static async Task<bool> ObjectExistsAsync(IAmazonS3 s3, string bucket, string key)
    {
        try
        {
            await s3.GetObjectMetadataAsync(new GetObjectMetadataRequest
            {
                BucketName = bucket,
                Key = key
            });
            return true;
        }
        catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return false;
        }
    }

    private static SftpClient CreateSftpClient(SftpConnectionConfig config)
    {
        using var keyStream = new MemoryStream(Encoding.UTF8.GetBytes(config.PrivateKeyPem));
        var keyFile = new PrivateKeyFile(keyStream);
        var connectionInfo = new ConnectionInfo(
            config.Host,
            config.Port,
            config.Username,
            new PrivateKeyAuthenticationMethod(config.Username, keyFile));
        return new SftpClient(connectionInfo);
    }

    private static async Task<SftpConnectionConfig> LoadConnectionConfigAsync(string ssmPrefix, RegionEndpoint region)
    {
        using var ssm = new AmazonSimpleSystemsManagementClient(region);

        var host = await GetParameterAsync(ssm, $"{ssmPrefix}/host");
        var portText = await GetParameterAsync(ssm, $"{ssmPrefix}/port");
        var username = await GetParameterAsync(ssm, $"{ssmPrefix}/username");
        var privateKey = await GetParameterAsync(ssm, $"{ssmPrefix}/private-key", withDecryption: true);

        if (!int.TryParse(portText, out var port))
        {
            port = 22;
        }

        return new SftpConnectionConfig(host, port, username, privateKey);
    }

    private static async Task<string> GetParameterAsync(
        IAmazonSimpleSystemsManagement ssm,
        string name,
        bool withDecryption = false)
    {
        var response = await ssm.GetParameterAsync(new GetParameterRequest
        {
            Name = name,
            WithDecryption = withDecryption
        });

        var value = response.Parameter.Value;
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"SSM parameter {name} is empty.");
        }

        return value.Trim();
    }

    private static string RequireEnv(string name)
    {
        var value = Environment.GetEnvironmentVariable(name);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"SftpPullIngest: {name} environment variable is not set.");
        }

        return value;
    }

    private static long ParseLongEnv(string name, long defaultValue)
    {
        var text = Environment.GetEnvironmentVariable(name);
        return long.TryParse(text, out var value) ? value : defaultValue;
    }

    private static string NormalizePrefix(string prefix)
    {
        if (string.IsNullOrWhiteSpace(prefix))
        {
            return "raw/";
        }

        return prefix.EndsWith('/') ? prefix : $"{prefix}/";
    }

    private static string NormalizeSsmPrefix(string prefix)
    {
        if (string.IsNullOrWhiteSpace(prefix))
        {
            return "/sftp-pull";
        }

        return prefix.StartsWith('/') ? prefix.TrimEnd('/') : $"/{prefix.TrimEnd('/')}";
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
            throw new InvalidOperationException("SftpPullIngest: could not determine AWS region.");
        }

        return RegionEndpoint.GetBySystemName(regionName);
    }
}

internal record SftpConnectionConfig(string Host, int Port, string Username, string PrivateKeyPem);

public record Input;

public record Response(int Processed, int Skipped, IReadOnlyList<string> Errors);
