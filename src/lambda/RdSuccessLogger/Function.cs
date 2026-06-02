using System.Text.Json;
using Amazon.Lambda.Core;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace RdSuccessLogger;

public class Function
{
    private const string SuccessMessage =
        "R&D S3-EventBridge-Lambda integration test successfully done";

    public Task FunctionHandler(JsonElement input, ILambdaContext context)
    {
        LambdaLogger.Log($"{SuccessMessage}");
        LambdaLogger.Log($"event detail: {JsonSerializer.Serialize(input)}");
        return Task.CompletedTask;
    }
}
