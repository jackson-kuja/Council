using System.Text.Json;
using GitHub.DistributedTask.WebApi;
using GitHub.Runner.Sdk;
using GitHub.Services.Common;
using GitHub.Services.OAuth;

static string Scrub(string? input)
{
    var text = input ?? string.Empty;
    text = System.Text.RegularExpressions.Regex.Replace(
        text,
        @"[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}",
        "<guid>"
    );
    text = System.Text.RegularExpressions.Regex.Replace(
        text,
        @"[A-Za-z0-9_-]{80,}",
        "<opaque>"
    );
    return text.Length > 3000 ? text[..3000] : text;
}

using var document = JsonDocument.Parse(await File.ReadAllTextAsync("route.json"));
var root = document.RootElement;
var endpoint = root.GetProperty("endpoint").GetString()
    ?? throw new InvalidOperationException("endpoint missing");
var scope = Guid.Parse(root.GetProperty("scope").GetString()!);
var hub = root.GetProperty("hub").GetString()
    ?? throw new InvalidOperationException("hub missing");
var plan = Guid.Parse(root.GetProperty("plan").GetString()!);
var timelineId = Guid.Parse(root.GetProperty("timeline").GetString()!);
var token = Environment.GetEnvironmentVariable("ACTIONS_RUNTIME_TOKEN")
    ?? throw new InvalidOperationException("runtime token unavailable");

object output;
try
{
    var credentials = new VssCredentials(
        new VssOAuthAccessTokenCredential(token),
        CredentialPromptType.DoNotPrompt
    );
    var connection = VssUtil.CreateConnection(new Uri(endpoint), credentials);
    await connection.ConnectAsync();
    var client = connection.GetClient<TaskHttpClient>();
    var timeline = await client.GetTimelineAsync(
        scope,
        hub,
        plan,
        timelineId,
        changeId: null,
        includeRecords: true
    );
    var records = timeline?.Records?.ToArray() ?? Array.Empty<TimelineRecord>();
    output = new
    {
        success = true,
        connection_authenticated = connection.HasAuthenticated,
        timeline_id_match = timeline?.Id == timelineId,
        record_count = records.Length,
        log_reference_count = records.Count(item => item.Log?.Id != null),
        record_types = records
            .Select(item => item.RecordType)
            .Where(item => item != null)
            .Distinct()
            .OrderBy(item => item)
            .ToArray(),
        record_names = records
            .Select(item => item.Name)
            .Where(item => item != null)
            .Take(40)
            .ToArray(),
        log_ids = records
            .Select(item => item.Log?.Id)
            .Where(item => item != null)
            .Take(40)
            .ToArray()
    };
}
catch (Exception error)
{
    output = new
    {
        success = false,
        exception_type = error.GetType().FullName,
        message = Scrub(error.Message),
        inner_type = error.InnerException?.GetType().FullName,
        inner_message = Scrub(error.InnerException?.Message),
        stack = Scrub(error.ToString())
    };
}

await File.WriteAllTextAsync(
    "sdk-result.json",
    JsonSerializer.Serialize(
        output,
        new JsonSerializerOptions { WriteIndented = true }
    ) + Environment.NewLine
);
