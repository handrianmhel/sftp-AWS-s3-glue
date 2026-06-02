using System.Globalization;
using System.Text.Json;
using Amazon.Lambda.Core;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace RdSuccessLogger;

public class Function
{
    private const string SuccessSuffix =
        "R&D S3-EventBridge-Lambda integration test successfully done";

    public Task FunctionHandler(JsonElement input, ILambdaContext context)
    {        
        var filename = TryGetString(input, "detail", "object", "key") ?? "unknown_filename";

        var sizeBytes = TryGetInt64(input, "detail", "object", "size") ?? 0L;
        var sizeMb = sizeBytes / (1024d * 1024d);

        var eventTimeUtcRaw = TryGetString(input, "time");
        var timestampSg = FormatSingaporeTime(eventTimeUtcRaw);

        var message =
            $"@@@ The {filename} file has been successfully uploaded last {timestampSg}. It is {sizeMb:0.##} MB. {SuccessSuffix}";

        LambdaLogger.Log($"{message}. See event's detail below (next log).");
        LambdaLogger.Log($"event detail: {JsonSerializer.Serialize(input)}");


        return Task.CompletedTask;
    }

    private static string FormatSingaporeTime(string? eventTimeUtcRaw)
    {
        if (string.IsNullOrWhiteSpace(eventTimeUtcRaw) ||
            !DateTimeOffset.TryParse(eventTimeUtcRaw, CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                out var utc))
        {
            return "unknown time";
        }

        var tz = TimeZoneInfo.FindSystemTimeZoneById("Asia/Singapore");
        var sg = TimeZoneInfo.ConvertTime(utc, tz);

        return sg.ToString("MMM d, yyyy hh:mm:ss tt", CultureInfo.InvariantCulture);
    }

    private static string? TryGetString(JsonElement root, params string[] path)
    {
        var cur = root;
        
        foreach (var p in path)
        {
            if (!cur.TryGetProperty(p, out cur)) return null;
        }

        return cur.ValueKind == JsonValueKind.String ? cur.GetString() : null;
    }

    private static long? TryGetInt64(JsonElement root, params string[] path)
    {
        var cur = root;

        foreach (var p in path)
        {
            if (!cur.TryGetProperty(p, out cur)) return null;
        }

        if (cur.ValueKind == JsonValueKind.Number && cur.TryGetInt64(out var v)) return v;
        
        return null;
    }
}